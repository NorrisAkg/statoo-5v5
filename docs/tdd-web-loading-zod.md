# Boutons réseau et validation Zod — 16 octobre 2026

Scénarios et résultats attendus écrits avant le code applicatif. Le périmètre
couvre les appels déclenchés par les boutons (connexion/création, actualisation,
déconnexion, réessais, mutations administratives, publication sport/finance,
soldes, décisions et transferts). Les lectures périodiques ne font pas apparaître
un chargement sur un bouton sans action utilisateur.

| ID | Cas nominaux, variantes et erreurs prévus | Résultat attendu |
| --- | --- | --- |
| LOAD-01 | Actualisation retardée, double clic, activation clavier, succès et erreur réseau/503 | Spinner visible, libellé accessible conservé, `aria-busy=true`, bouton désactivé ; une seule action ; état et libellé restaurés dans tous les cas. |
| LOAD-02 | Connexion et création de groupe retardées ; soumissions répétées par Entrée ; erreur d'authentification | Même indicateur et verrou ; pas de seconde requête ni effacement d'une erreur ; réactivation après échec. |
| LOAD-03 | Validation d'un formulaire modal, confirmation annulée/acceptée, relecture lente après écriture, erreur 403/422/503 | Bouton de soumission indique l'action en cours jusqu'à son terme ; actions concurrentes du même formulaire bloquées, sans bloquer le dialogue de confirmation ; saisies conservées après refus et possibilité de réessayer. |
| LOAD-04 | Publication d'un brouillon sportif/financier, approbation/arbitrage/transfert, réessai de file et déconnexion | Tous les boutons réseau utilisent le même comportement ; résultats et règles d'idempotence existantes préservés. |
| LOAD-05 | Champ invalide, action synchrone locale, fin d'action sur bouton retiré du DOM, bouton préalablement indisponible | Pas de requête pour une saisie invalide ; pas de spinner persistant ni exception ; état désactivé initial respecté. Les champs/boutons locaux ne reçoivent pas de faux chargement réseau durable. |
| LOAD-06 | Clair/sombre, largeur 320/390/1440, préférence de réduction des animations | Indicateur contrasté, taille de bouton stable, texte lisible ; animation désactivée si demandée sans masquer l'état de chargement. |
| ZOD-01 | Connexion/création valides ; identifiants/noms vides ou blancs, limites 100/200, mot de passe <8 ou >200, membres absents ou >1000 | Schémas Zod réutilisables ; validation avant réseau ; erreurs lisibles en français sans JSON technique ni valeur de mot de passe. Les identifiants historiques restent acceptés. |
| ZOD-02 | Membres et comptes, rôles inconnus/absence de responsabilité, transfert/décision sans cible, révision négative, motif vide ou >300 | Refus local avant confirmation/envoi ; chemins de champs disponibles ; rôle MEMBER seul n'est pas un nouveau responsable. Métadonnées des membres conservées. |
| ZOD-03 | Montants et statistiques : 0, chaîne numérique, borne 10^12, négatif, décimal, NaN/Infinity, booléen/null, champ blanc ; minimum sportif 1/2/6/30/31 | Conversion contrôlée par Zod ; pas de conversion de booléen/null/blanc en zéro ; bornes respectées. Avances initiales signées autorisées ; pénalités et caisse non négatives. |
| ZOD-04 | Sport/finance valides et structures invalides (session/lignes/participants absents ou mauvais type), dates inexistantes, doublons, équipes, scores et pénalités incohérents | Erreurs de validation métier lisibles ; pas de TypeError ; règles existantes conservées et payload mobile compatible. Aucun changement des règles de clôture. |
| ZOD-05 | Solde avec date absente/valide/inexistante, avances négatives ; paramètres financiers/sportifs ; approbation et rotation d'accès | Validation locale cohérente avec l'API. Les valeurs saisies ne disparaissent pas après refus. |
| ZOD-06 | Refus Zod dans un formulaire, puis correction et nouvel envoi ; création invalide avant préparation incertaine | Message français associé aux champs identifiables, `aria-invalid` et aide accessibles ; erreurs retirées lors d'une nouvelle validation réussie. Une création refusée localement n'est pas marquée comme publication incertaine. |
| ZOD-07 | Déploiement statique propre sous /portal/ ou à la racine ; rechargement hors ligne après installation du shell | Zod livré localement, version directe verrouillée, pas de CDN/import bare dans le navigateur. Module de validation et dépendance présents dans le paquet et le cache PWA. |

Les contrôles automatisés seront exécutés séparément des essais physiques
Android/iOS, Safari et lecteurs d'écran. Preuves RED/GREEN dans
`docs/web-loading-zod-results/`. Les règles serveur restent indépendantes de la
validation client.

Cas découvert avant sa correction : ZOD-06b — une erreur strictement locale sur
l'identifiant ne doit pas effacer les mots de passe déjà saisis ; le formulaire
n'a encore rien envoyé. Après une véritable tentative réseau, l'effacement
existant des mots de passe reste appliqué.

Cas découvert avant sa correction : LOAD-03b — Échap pendant une requête de
formulaire ne doit pas fermer le dialogue et masquer son état d'envoi. La sortie
par Échap redevient disponible après le résultat ; le dialogue de confirmation
reste annulable avant l'envoi.

## Implémentation et résultats

### Chargement des actions

`button-state.mjs` centralise l'état : spinner, `aria-busy`, verrou immédiat,
restauration des états désactivés et nettoyage dans `finally`. Les formulaires
verrouillent aussi les autres actions/champs pendant leur opération et empêchent
leur fermeture par Échap pendant l'envoi. Le dialogue de confirmation reste
annulable avant publication. La largeur du bouton ne change pas et le libellé
accessible est conservé. La préférence de réduction des animations est respectée.

Le même comportement équipe connexion/création, actualisation, déconnexion,
réessai de file et toutes les soumissions des dialogues, y compris sport,
finances, gestion, ouverture des soldes et décisions. Les actions de consultation
locale et les lectures périodiques ne simulent pas un appel réseau utilisateur.

### Validation client

Zod **4.6.7** est une dépendance directe verrouillée. Les schémas de
`web/validation.mjs` valident les identifiants, mots de passe, membres/comptes,
rôles, montants, dates, paramètres, soldes, décisions/transferts et structures
sportives/financières. Les contrôles métier contextuels existants restent en place.
Les mutations sont vérifiées avant confirmation et à la frontière du client.
La création est validée avant de marquer une publication comme incertaine.

Les erreurs présentent un texte français sans JSON technique ni valeur de mot de
passe ; les champs identifiés reçoivent `aria-invalid` et une aide reliée par
`aria-describedby`. Les erreurs purement locales conservent les mots de passe.
L'effacement après véritable tentative réseau garde le comportement antérieur.

Les exports Zod nécessaires sont assemblés par esbuild dans
`web/vendor/zod.mjs` (~95 Ko), avec leur licence. La commande `npm run vendor:web`
permet de régénérer cet asset lors d'une mise à jour de Zod. Aucun CDN ni import
npm non résolu dans le navigateur ; validation, dépendance et helpers de boutons
sont livrés dans le portail statique et précachés par la PWA.

Référence de l'API utilisée : [Zod, basic usage](https://zod.dev/basics).

### Preuves observées

| Exécution | Résultat |
| --- | --- |
| Tests unitaires ajoutés, avant code | **6 échecs comportementaux, 1 réussite** : données invalides acceptées, conversions booléen/null/blanc, structures sans erreur exploitable et absence d'erreurs structurées. [RED](web-loading-zod-results/unit-red.txt) |
| Tests UI avant code | Attentes de `aria-busy` échouées sur les neuf cas de chargement. La trace brute contient aussi un premier essai avec mauvais libellé du champ ; ce timeout n'est pas une preuve produit. Voir réserves de trace ci-dessous. |
| Livraison statique/cache avant correction correspondante | **2 échecs, 2 réussites** : module absent du paquet et du cache. [RED](web-loading-zod-results/packaging-red.txt) |
| ZOD-06b avant correction | Mot de passe attendu conservé, obtenu vide. [RED](web-loading-zod-results/local-password-red.txt) |
| LOAD-03b avant correction | Dialogue attendu présent pendant envoi, obtenu fermé après Échap. [RED](web-loading-zod-results/modal-escape-red.txt) |
| Tests unitaires ciblés, après code | **7 réussites**. [GREEN](web-loading-zod-results/unit-green.txt) |
| Tests UI ciblés, après code | **10 réussites**. [GREEN](web-loading-zod-results/browser-green.txt) |
| Paquet statique et cache PWA | **4 réussites**. [GREEN](web-loading-zod-results/packaging-green.txt) |
| `npm run test:web` | **52 tests réussis, 0 échec**, dont les sept nouveaux. [Régression](web-loading-zod-results/unit-regression.txt) |
| `npm run test:web:browser` | **99 tests réussis, 0 échec**, dont les dix nouveaux et le lot sportif du chat voisin. [Régression](web-loading-zod-results/browser-regression.txt) |
| Contrôle visuel | Loader inspecté à 320 px en clair et 390 px en sombre ; captures locales sous `mobile/build/loading-zod/`. Ce ne sont pas des essais sur téléphone physique. |
| `git diff --check` | Sans erreur. |

Réserves : deux lancements RED UI se sont chevauchés au début ; le premier
cherchait « Identifiant » au lieu de « Identifiant de connexion ». La trace brute
`browser-red.txt` contient des portions/footers superposés : ne pas additionner ses
résumés et ne pas compter ce timeout comme défaut applicatif. Les assertions de
chargement et les traces unitaires indépendantes restent exploitables. Le harnais
de réessai a également dû remettre son serveur simulé en succès après avoir
provoqué un 422 ; ce réglage du harnais n'est pas une preuve RED produit.

## Limites et coordination

Les tests automatisés couvrent notamment doubles activations, erreurs réseau,
annulation de confirmation, retour au formulaire, chargement sur petits/grands
écrans, erreurs Zod et correction, clavier et hors connexion. Ils ne certifient
pas toutes les combinaisons de chaque formulaire. Safari/iOS, installation réelle
de PWA et annonces TalkBack/VoiceOver restent à contrôler sur appareil.

La validation finale a été coordonnée, sur autorisation utilisateur, avec le chat
du parcours sportif. Ses étapes, helpers, données de joueurs archivés et tests de
coupure de texte ont été conservés. Aucune incompatibilité restante observée dans
la régression commune. Aucun changement backend/mobile requis par ce lot ; les
tests API de l'autre lot ne sont pas présentés comme réexécutés ici.

Aucun commit, push ni déploiement effectué.
