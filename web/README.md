# Statoo Web — PWA et gestion par rôle

Depuis le lot de parité du 16 octobre 2026, la cible web commune se trouve dans `mobile/lib/main_web.dart` : les mêmes écrans et processus Flutter servent le navigateur et le mobile, avec SQLite persistant dans le navigateur. Le build Vercel préparé utilise `bash scripts/build-universal-web.sh` et publie `web/universal-dist/`. Le portail HTML décrit ci-dessous reste disponible sous `/portal/` pour conserver l'accès aux préparations historiques ; leurs données ne sont pas migrées automatiquement. Aucun déploiement n'est déclenché par cette documentation.

Contrat et recette : `docs/parite-web-mobile.md`. Pour une compilation locale sous Windows : depuis `mobile`, exécuter `flutter pub get`, `dart run sqflite_common_ffi_web:setup`, puis `flutter build web --release --target lib/main_web.dart --no-web-resources-cdn --dart-define=STATOO_API=https://statoo-api.onrender.com`. À la racine, `npm run build:web` prépare l'ancien portail et `node scripts/package-universal-web.mjs` assemble les deux dans `web/universal-dist/`. Servir ce dossier à la racine d'une origine HTTP locale/HTTPS pour tester le stockage et le service worker.

Tests navigateur communs : servir `web/universal-dist/` sur `127.0.0.1:18087`, lancer `backend/.venv/Scripts/python.exe web/tests/serve-parity.py` (API en mémoire sur 18088), puis `npm run test:web:parity`. Ces tests ne contactent aucune base de production.

HTML/CSS, Poppins embarquée et modules JavaScript natifs. La PWA réutilise l'API FastAPI et les identifiants du mobile.

Les actions réseau affichent un indicateur dans leur bouton et bloquent les
activations répétées jusqu'au résultat. Les formulaires utilisent les schémas
Zod de `validation.mjs`, avec messages français et aides de champ accessibles.
Zod est livré localement dans `vendor/zod.mjs` et disponible hors connexion ;
`npm run vendor:web` régénère cet asset après une mise à jour de la dépendance.
Les règles serveur restent nécessaires. Scénarios et preuves dans
[le journal TDD](../docs/tdd-web-loading-zod.md).

L'en-tête et le favicon utilisent `web/icons/logo-transparent.png`, une version détourée de l'emblème du logo natif. Le nom reste affiché à côté dans l'en-tête. L'original natif est conservé. Ces ressources sont disponibles hors connexion. Sur grand écran, le contenu est limité à 1280 px, l'introduction reste alignée en haut et les accès Admin/collectif utilisent deux colonnes ; les petits écrans conservent un empilement vertical. Les trois équipes d'un tournoi sont en colonnes à partir de 1100 px.

```powershell
python -m http.server 8080 --directory web
npm run test:web
```

Depuis la racine du dépôt. Ouvrir `http://localhost:8080`.

`npm start` sert l'API et la PWA sur `http://127.0.0.1:8000/portal/`. Un hébergement statique peut servir `web/dist/` après `npm run build` ; renseigner alors son origine dans `CORS_ORIGINS` du backend et l'adresse HTTPS de l'API dans `STATOO_PUBLIC_API_URL` avant compilation. Les chemins relatifs fonctionnent sous `/portal/` ou à la racine.

## Parcours

- Membres et Censeur : consultation, via accès collectif ou compte existant. Les nouveaux comptes individuels sont réservés aux responsables.
- Admin : créer un groupe avec membres et accès collectif, gérer/archiver/réactiver les membres, créer les comptes responsables, attribuer/transférer les rôles, renouveler l'accès collectif.
- Admin/Président/Vice-président/SG/SGA : composer un match ou tournoi, tirage équilibré, couleurs, statistiques, brouillon, clôture, correction motivée et annulation.
- TR/TGA : proposer les soldes initiaux ; saisir/corriger les points liés à une séance ou indépendants, avec cotisations, pénalités, dons et dépenses séparés.
- PDT/VP : approuver la proposition exacte de soldes, comparer/arbitrer les versions et transférer les responsabilités.
- Admin/TR/TGA : paramètres financiers des nouvelles échéances.

L'API applique les mêmes contrôles que pour le mobile. Admin seul ne donne pas de droits sportifs ou de trésorerie. Les montants sont des entiers en F.

### Préparer et saisir une séance

Le parcours sportif suit quatre étapes : **Options → Présents → Équipes → Match**.
Les étapes et les actions restent accessibles pendant le défilement.

- **Options** : date, format match/tournoi, classement, effectifs inégaux et référence commune aux finances.
- **Présents** : recherche par nom ou surnom, sans distinction de casse ou d’accents. Les actions collectives s’appliquent aux joueurs affichés ; les sélections masquées par la recherche sont conservées. Les archivés déjà liés à une séance restent consultables.
- **Équipes** : effectifs et joueurs à placer, couleurs et répartition équilibrée en nombre. Une affectation manuelle reste possible.
- **Match** : scores ou victoires avec +/− et saisie numérique ; bouton Statistiques sur chaque joueur pour ouvrir ses buts, passes et cartons. Une seule fiche détaillée est ouverte à la fois.

Une séance existante s’ouvre directement sur Match. Les autres étapes restent
accessibles pour modifier ses options ou sa composition. Une correction ou
annulation publiée demande toujours un motif.

La préparation locale conserve l’étape, les sélections, les équipes et les
statistiques après fermeture ou rechargement pour le même compte. Retirer puis
réintégrer un présent dans cette préparation retrouve ses statistiques ; seuls
les présents sont transmis lors d’une publication. Un refus de stockage est
signalé explicitement, sans annoncer la préparation comme conservée.

Les compteurs ne publient rien automatiquement. **Enregistrer le brouillon**
publie une version brouillon pour le groupe ; **Clôturer la séance** publie le
résultat terminé. Ces actions passent par un récapitulatif et une confirmation.
Les contrôles existants (minimum du groupe, composition, scores, passes,
couleurs et versions concurrentes) restent appliqués.

Scénarios et preuves : `docs/tdd-web-parcours-sportif.md` et
`docs/web-sport-results/` depuis la racine du dépôt.

À la création, le serveur attribue un identifiant aléatoire `#` suivi de huit chiffres. Les collisions déclenchent un nouveau tirage et la clé primaire garantit l'unicité. L'identifiant est affiché sur l'accueil et sert à rejoindre le groupe ; les identifiants historiques restent valides. La liste initiale des membres accepte les virgules et les retours à la ligne, supprime les espaces autour des noms et ignore les entrées vides. L'identifiant collectif est l'accès partagé de consultation des membres.

Une PWA chargée auparavant permet de préparer le nom et les membres hors connexion. « Enregistrer sur cet appareil » conserve cette préparation ; « Reprendre la préparation » la retrouve après rechargement. Le retour du réseau ne publie rien automatiquement : définir les accès Admin et collectif puis créer le groupe. Aucun mot de passe n'est conservé dans cette préparation. L'effacement des données du navigateur la supprime ; une première visite sans réseau reste impossible.

Lors d'une publication incertaine, nom et membres sont figés et la même référence d'opération est réutilisée après rechargement. Ressaisir les mêmes accès : le serveur retrouve le groupe déjà créé au lieu d'en créer un second. La table `registration_operations`, créée au démarrage du backend, assure cette unicité entre tentatives. Les informations permettant de vérifier la reprise sont stockées sous forme d'empreinte salée ; les mots de passe ne sont pas stockés en clair. Les anciennes créations sans référence d'opération restent compatibles mais ne bénéficient pas de cette garantie de reprise.

## Installation et hors ligne

Les icônes natives sont réutilisées : 192/1024 px et icône iOS 180 px. L'installation nécessite HTTPS ou localhost en développement. Le bouton n'apparaît que si le navigateur fournit une invite ; sur Safari, utiliser Partager → Sur l'écran d'accueil. L'installation physique sur Android/iOS reste à vérifier séparément.

Le service worker conserve uniquement les fichiers publics. Aucune réponse API ou requête authentifiée n'est mise dans ce cache. À chaque livraison modifiant ces fichiers, changer la version `CACHE` de `sw.js`. La mise à jour propose un bouton explicite avant rechargement.

Le jeton reste dans `sessionStorage`. Les données consultées, brouillons sportifs/financiers et opérations sont dans `localStorage`, séparés par serveur/groupe/compte. La dernière actualisation est affichée. Un rechargement hors ligne permet la consultation et la saisie d'un brouillon si la connexion de l'onglet reste valide ; fermer la session du navigateur peut nécessiter une reconnexion en ligne.

Chaque envoi métier est persisté avec son identifiant avant le réseau. Après un timeout, « Réessayer les envois » renvoie le corps exact sans doubler l'opération. Un refus explicite 403/409/422 permet de corriger le brouillon. Une version concurrente attend un arbitrage et n'est pas annoncée comme publiée. Les actions administratives nécessitent le réseau ; aucune décision n'est rejouée automatiquement.

Déconnexion ou 401 : suppression du jeton et des données/brouillons locaux du compte. Un changement de compte ne rejoue jamais ses opérations sous la nouvelle identité. Fermer un formulaire conserve son brouillon ; se déconnecter l'efface.

## Tests

```powershell
npm install
npm run test:web
# Terminal séparé : API isolée, mémoire uniquement
backend/.venv/Scripts/python.exe web/tests/serve.py
# Chrome installé requis
npm run test:web:browser
npm run build:web
npm run build
```

`STATOO_TEST_URL` change l'origine de test (défaut : `http://127.0.0.1:18085`). `STATOO_PLAYWRIGHT` permet un package Playwright alternatif. `STATOO_QA_OUTPUT` enregistre les captures dans un dossier local ignoré, par exemple `mobile/build/pwa-qa/`.

Le test intégré crée des groupes synthétiques sur cette API isolée, effacés à l'arrêt. Ne pas lancer ce test sur la production. Scénarios et preuves : `docs/tdd-web-pwa.md`.

Le contrat de synchronisation conserve le format SQLite du mobile : noms/couleurs JSON texte, flags sportifs en 0/1. `node web/tests/export-mobile-fixture.mjs` régénère le fixture contractuel, puis `flutter test test/features/shared/pwa_wire_import_test.dart` depuis `mobile/` vérifie son import par le service mobile réel sur une base en mémoire. Un test Node vérifie également que ce fixture reste conforme au sérialiseur courant.

L'alignement porte sur les workflows gérés par l'API. Les réglages propres au téléphone, sauvegardes SQLite et statistiques avancées MVP du mobile ne sont pas transférés par cette API et ne sont pas ajoutés à cette PWA.
# Adresse du serveur

## Déploiement sur Vercel

Importer la racine du monorepo (Root Directory : `.`), sur une branche contenant
le portail actuel, le `package.json`, le verrou et `vercel.json` racine.
La configuration versionnée impose Other, `npm ci`, `npm run build:web` et
la sortie `web/dist`. Node.js 22 est compatible avec le script de build.
Ne pas sélectionner Nuxt ou utiliser `nuxt generate` : ce portail est statique.
Un log contenant encore `generate` / `nuxt` indique une autre révision ou racine.

Définir `STATOO_PUBLIC_API_URL` avec l'origine HTTPS du backend dans les variables
Vercel avant le build, puis autoriser l'origine du site dans `CORS_ORIGINS` côté
backend. Vercel sert ici uniquement la PWA ; l'API FastAPI doit être hébergée
séparément. Sans cette variable, les appels API viseraient le site statique.
Après modification, lancer un nouveau déploiement de la branche à jour.

Les formulaires ne demandent aucune adresse technique. Dans le `.env` à la racine :

```dotenv
STATOO_PUBLIC_API_URL=
```

Vide ou absent : la PWA utilise l'origine du site. Pour une API hébergée séparément, renseigner par exemple `https://api.exemple.fr`. Seules les URL HTTP(S) sans identifiants, paramètres ou fragment sont acceptées ; un préfixe de chemin est possible.

FastAPI charge `.env.local` puis `.env` au démarrage, sans remplacer les variables déjà définies dans l'environnement. Redémarrer le serveur après modification. Pour un hébergement statique, `npm run build:web` applique la même priorité et génère uniquement l'adresse publique dans `web/dist/config.json` ; reconstruire et republier après modification. Le `.env` et ses secrets ne sont jamais copiés dans le portail. Une API sur une autre origine doit autoriser l'origine du portail dans sa configuration CORS.

Une session déjà ouverte conserve son serveur d'origine. Se déconnecter puis se reconnecter pour utiliser la nouvelle configuration. Une PWA installée conserve la configuration de son shell jusqu'à l'activation de sa mise à jour.
