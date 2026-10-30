# Résumé des exécutions — 25 octobre 2026

Référence : 1daa008, staging. Environnement Linux local, Chrome de bureau.

## Suite Flutter existante

Commande exécutée dans mobile : `flutter test --reporter compact`.
Résultat observé : `07:08 +825: All tests passed!`, code de sortie 0.
Le flux compact a été reçu dans les sorties d’outils de cette session ; ce fichier
en conserve le résumé, pas une transcription exhaustive.

## Analyse et compilation

- `flutter analyze --no-pub` : 134 diagnostics, dont 2 warnings et 132 infos ; aucune erreur. Voir flutter-analysis.txt.
- `flutter build web --release --target lib/main_web.dart --no-web-resources-cdn --dart-define=STATOO_API=http://127.0.0.1:19226` : succès, 358,2 s. Voir flutter-build.txt.
- `npm run build:web` puis `node scripts/package-universal-web.mjs` : succès. Voir web-unit-and-package.txt et universal-package.txt.
- `backend/.venv/bin/python -m pip check` : No broken requirements found. Ce n’est pas un scan CVE.

## Suites serveur et navigateur

- Backend depuis backend : `.venv/bin/python -m pytest -q -p no:cacheprovider` : 89 passed, 1 warning, 494.80 s ; backend-tests.txt.
- `STATOO_TEST_URL=http://127.0.0.1:19226 npm run test:web:browser` : passage final 110/110 ; legacy-browser-final.txt.
- `STATOO_MANAGER_API=http://127.0.0.1:19226 STATOO_MANAGER_URL=http://127.0.0.1:19225/ node --test web/tests/manager-access.e2e.mjs` : passage final 1/1 ; manager-browser-final.txt.
- Focus iOS simulé et enveloppe Flutter : 3/3 ; responsive-browser.txt. La simulation CSS Chromium ne démontre pas le clavier iOS.
- `RSP_FULL=1 node --test web/tests/responsive-flutter.e2e.mjs` : 1 test composé réussi, 18 configurations largeur/texte/thème, 83,26 s ; responsive-browser-full.txt. Périmètre : bienvenue, création et enveloppe navigateur.
- `npm audit --json` : aucune vulnérabilité signalée sur le graphe npm examiné ; npm-audit.json.

## Sondes complémentaires

Scénarios définis dans scenarios.md avant les scripts. Aucun correctif.

- probe_api.py : 17 observations ; api-probes.json. API et données en mémoire.
- probe_flutter_test.dart : trois échecs comportementaux ; flutter-probes-historical.txt. La fixture historique est le schéma exact de 1a3af10 ; la première fixture dérivée de v8 est exclue de la preuve migration.
- probe_sync_test.dart : deux échecs comportementaux ; sync-probes.txt.
- probe_sql.py : 50 joueurs, 500 séances, 5 000 participations ; sql-benchmark.json.

## Parcours interactif effectivement observé

Navigateur intégré, origine locale dédiée, thème clair, largeur visible d’environ
432 px : introduction → création → six joueurs fictifs → accès Admin → choix
Continuer sur cet appareil → séance classique 3v3 → tirage → démarrage explicite
→ but Alice/passe Fatou → clôture → célébration → classement → statistiques.

Contrôlé : victoire 1-0, gagnants à 3 points/perdants à 0, total groupe 1 séance,
1 but et 1 passe. Point financier ouvert : 6 cotisations préremplies à 100 F,
total provisoire 600 F ; dialogue de confirmation d’abandon vu, brouillon abandonné.
Aucun encaissement réel ni écriture dans un groupe utilisateur.

AUD-18 complément : rechargement direct de Stats reproduit deux fois un faux état
vide ; les données se rétablissent en passant par l’accueil. Voir reload-observations.md.

Constats accessibles : Retour création, retrait initial et bouton flottant séances
sans nom ; commandes de composition répétées sans joueur ; nom de groupe doublé
sur l’accueil. Contrastes et cadrage n’ont pas tous été appréciés visuellement.

## Incidents d’environnement

Le premier pytest lancé depuis la racine n’avait pas app dans son chemin d’import.
Les TestClient démarrés dans le bac à sable se sont bloqués ; les passages finaux
ont été exécutés hors de cette restriction avec SQLite explicite en mémoire.
Le cache SDK Flutter exigeait aussi l’accès hors du bac à sable.

Premier essai gestionnaire : CORS de l’API d’audit non configuré ; second : serveur
statique interrompu ; troisième : réussi. Le premier run du portail a subi une
interruption du serveur et un timeout ; son passage final 110/110 les remplace.
Ces incidents ne sont pas comptés comme défauts applicatifs.

Les résultats prouvent les périmètres décrits. Aucune validation physique Android,
iPhone, lecteur d’écran, PostgreSQL de production ou déploiement public n’en découle.
