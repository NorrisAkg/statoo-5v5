# Accueil web — scénarios avant implémentation

Base : staging 4266cda. Références lues : design-system, thèmes Flutter et web, PrimaryButton, splash_screen et onboarding_screen mobiles, formulaires web.

| ID | Scénario | Résultat attendu |
|---|---|---|
| ACC01 | Première ouverture | Splash bref avec logo, puis les trois étapes et textes du mobile, illustrations SVG décoratives. |
| ACC02 | Suivant, précédent, passer, commencer | Navigation clavier possible ; passer/commencer rejoignent la connexion ; fin mémorisée ; rechargement sans répétition. |
| ACC03 | Stockage indisponible, réseau absent, mouvement réduit | Aucun blocage ; onboarding utilisable ; animations désactivées si demandé. Une session ou préparation existante rejoint directement son parcours. |
| ACC04 | Champs de connexion/création et champs partagés | Placeholder explicite, label permanent ; aucune valeur fictive envoyée à la place de la saisie. |
| ACC05 | Chaque mot de passe | Masqué initialement ; bouton œil nommé, bascule indépendante, valeur et focus conservés, aucun envoi du formulaire. |
| ACC06 | Défilement | Barre supérieure visible en haut, sans masquer le champ ciblé ; clair/sombre. |
| ACC07 | Nom court absent, vide ou espaces | Nom complet utilisé ; ancien client et ancien groupe compatibles. |
| ACC08 | Nom court fourni (Unicode), limite 30, dépassement | Espaces extérieurs retirés ; 30 caractères acceptés, 31 refusés côté client et serveur ; snapshot et titre principal utilisent le nom court, nom complet disponible. |
| ACC09 | Préparation hors ligne et reprise | Nom court conservé après reload ; changement pris en compte ; publication incertaine verrouille les trois champs ; identité de reprise stable, aucun mot de passe stocké. |
| ACC10 | Publication/reconnexion/rôles | Nom court transmis et persisté ; affichage pour Admin et membres ; pas de changement de droits ; reprise identique acceptée, changement refusé. |
| ACC11 | Cadrage | 320/393 px, texte 100/130/200 %, clair/sombre : pas de défilement horizontal ; actions atteignables, noms longs et zones sûres. Clavier réel à contrôler séparément. |
| ACC12 | Régressions et livraison PWA | Tests backend/web existants ; ressources embarquées et version cache actualisée ; build statique valide. |

## Résultats

ACC13, découvert en aperçu PWA avant correction : HTML actualisé avec ancien JavaScript en cache. Attendu : aucun splash bloquant ; le splash doit être créé et retiré par la même version du JavaScript.

Précision ACC11 découverte en capture : « Commencer » était coupé à 320 px/130 % et 393 px/200 %. Test de lignes de texte ajouté avant correction : 2 lignes observées au lieu de 1. Les boutons doivent s'empiler quand leur largeur devient insuffisante.

### RED observé avant les corrections

- `welcome.test.mjs` : `undefined !== 'ÉFC'`, nom court absent du brouillon.
- `test_short_name.py` : 6 échecs comportementaux ; snapshot sans nom court, 31 caractères acceptés à tort (201 au lieu de 422).
- `welcome.e2e.mjs` : placeholder absent et étape « Suivez vos matchs 5v5 » inexistante.
- ACC13 : splash présent dans le HTML, assertion false attendue / true observée ; cas vu dans le navigateur avec ancien shell.
- ACC11 : bouton Commencer sur deux lignes à 320 px/130 % ; test ajouté puis correction en grille responsive.

### GREEN et régressions exécutées

- Backend : `backend/.venv/Scripts/python.exe -m pytest backend/tests -q` : **68 passed**, 176,56 s ; un avertissement de dépréciation Starlette/httpx préexistant.
- Unités web et build : **57 passed**, build statique réussi ; `welcome-build-results.txt`.
- Nouveaux tests navigateur : **4 passed** (`welcome-targeted-results.txt`) : publication du nom court, verrouillage/reprise, stockage inaccessible, placeholders, bascule des mots de passe, trois étapes, rechargement et matrice de cadrage.
- Inscription et reprise hors ligne existantes avec nouveaux tests : **5 passed** (`welcome-browser-results.txt`, avant ajout des deux cas ciblés supplémentaires).
- Suite navigateur existante : **98/99** au premier passage (`welcome-browser-regression.txt`). Le seul échec était un sélecteur partiel « Mot de passe personnel » qui trouvait aussi le nouveau bouton œil. Sélecteur rendu exact, test Admin rejoué : **1 passed** (`welcome-admin-regression.txt`). Pas de seconde exécution intégrale après cette correction de test et la grille de boutons ; les tests ciblés de grille ont été rejoués.
- `git diff --check` : aucune erreur sur les fichiers de ce lot.

### Écrans réellement observés et limites

- Aperçu local dans le navigateur intégré : splash et premier écran d'onboarding sombre.
- Captures examinées : formulaire clair 393 px, étape 1 claire, étape 3 sombre à texte 200 % avant/après correction de Commencer (`welcome-captures/`). Les autres captures sont disponibles, sans prétendre à une revue visuelle exhaustive.
- Contrôles automatisés de largeur : 320/393 px, texte du body 100/130/200 %, clair/sombre, formulaire et dernière étape ; contrôle de ligne du bouton Commencer. Ce changement CSS de taille ne remplace pas un zoom navigateur/OS réel.
- À contrôler manuellement : clavier mobile réel, lecteur d'écran, zones sûres sur appareil, installation/mise à jour d'une PWA de production et permissions de navigateur. Les régressions de rôles existantes ont été exécutées ; pas de validation visuelle exhaustive par rôle.
- Aucun déploiement, commit ou modification des données de production. `staging` mis à jour de eef1451 vers 4266cda ; modifications préexistantes préservées, y compris web/README.md remis après stash ciblé.
