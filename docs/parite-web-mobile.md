# Contrat de parité des parcours — 16 octobre 2026

Demande utilisateur : mêmes processus dans le navigateur et sur mobile, **mode local compris**, afin de retrouver ses repères en changeant d'environnement. Référence : application Flutter actuelle, pas l'ancien portail PWA. La présentation peut s'adapter à l'écran ; étapes, actions, validations, permissions et conséquences restent communes.

## Scénarios définis avant tout code de ce lot

| ID | Parcours, variantes et erreurs | Résultat attendu commun |
|---|---|---|
| PAR01 | Première visite, retour, thème, réseau absent | Splash → même onboarding en trois pages → création/reprise ; préférence conservée. |
| PAR02 | Groupe local sans serveur ; nom vide/long, choix format, localisation | Identité du groupe → ajout des joueurs → accueil ; aucune inscription ni requête API requise. |
| PAR03 | Plusieurs groupes, changement pendant saisie, suppression | Même sélecteur, isolation stricte des données et blocage des mutations sur groupe changé. |
| PAR04 | Joueur : ajout simple/en série, doublon, photo, annulation | Même formulaire et validations ; image lisible après reload ; aucun fichier natif requis sur web. |
| PAR05 | Joueurs : recherche, tri, fiche, historique, édition, archivage | Mêmes commandes et informations ; historique conservé, archivés exclus des nouvelles sélections collectives. |
| PAR06 | Nouvelle séance, nominal classique/tournoi, préparation invalide | Date & options → composition ; action explicite « Débuter la séance » ; pas de saisie de match avant démarrage. |
| PAR07 | Une séance active existe | Nouvelle séance enregistrée en brouillon ; démarrage de la suivante bloqué tant que l'active n'est pas libérée. |
| PAR08 | Brouillon en attente, démarrage, retour, reload | « Démarrer la séance » explicite ; mêmes validations et statut actif persistant. |
| PAR09 | Match actif : score, buts, passes, cartons, joueurs tardifs, équipes | Mêmes commandes et cohérence score/buteurs ; conservation du focus et des données. |
| PAR10 | Clôture invalide/valide, tournoi sans victoire, annulation, réouverture | Mêmes contrôles, confirmations, statuts et invalidations des agrégats. |
| PAR11 | Classements points/ratio/buteurs/passeurs/cartons, filtres et MVP | Mêmes calculs, départages, périodes, règles et réglages. |
| PAR12 | Statistiques groupe et joueur, états vides | Mêmes pages et agrégats, sans remplacer un absent par une valeur inventée. |
| PAR13 | Finance : initialisation, point, cotisation, retards, dépenses/dons | Mêmes écrans, onglets, confirmations et permissions ; saisies invalides préservées. |
| PAR14 | Création/rejoindre/publier groupe partagé ; collectif/gestionnaire | Même processus mobile, rôles et synchronisation ; serveur Render configuré. |
| PAR15 | Comptes, rôles, transfert, accès collectif, arbitrage, réserves | Mêmes actions, motifs, résumés et contrôles d'autorisation. |
| PAR16 | Sauvegarde et restauration : JSON, fusion/écrasement, annulation, invalide | Même format natif, prévisualisation et confirmations ; télécharger/choisir un fichier sur navigateur. |
| PAR17 | Fermeture/réouverture navigateur, offline après premier chargement | Groupe local et séance active conservés dans une base persistante du navigateur ; aucun compte obligatoire. |
| PAR18 | Transport web HTTPS/CORS, HTTP local, # dans identifiant, erreur serveur | Même contrat API ; URL correctement encodée ; erreurs récupérables et aucun secret dans le build. |
| PAR19 | 320/393 px, clair/sombre, texte 100/130/200 %, clavier et zones sûres | Mêmes composants Flutter et adaptations déjà testées ; recette navigateur spécifique distincte. |
| PAR20 | Livraison Vercel, ancien shell PWA et données existantes | Build reproductible ; ancien portail préservé tant que la migration des brouillons n'est pas validée ; ne pas déclarer les données historiques migrées sans test. |

PAR21 — synchronisation de l'état actif : une publication sportive contient `is_active` au niveau du payload (pas dans la ligne SQLite). Une seule séance active par groupe ; la clôture/annulation la libère ; un candidat en conflit ne l'active pas ; un arbitrage ne peut activer une seconde séance. Un ancien client sans ce champ reste compatible. Le snapshot expose `active_session_id`. Le mobile importe cette clé après les séances et préserve une action sportive locale encore en attente.

PAR22 — cas de revue, écrits avant correctif : (a) pour un groupe historique dont le serveur n'a jamais reçu d'état actif explicite, le snapshot omet la clé et conserve l'état local ; (b) deux appareils démarrent A et B hors ligne : le second reçoit un refus métier identifié, conserve B en brouillon, importe A comme active, signale le refus et continue les autres envois. Un refus réseau ou un autre HTTP 409 ne doit pas être transformé en succès ni supprimé. Le refus est conservé dans l'historique local et un redémarrage explicite peut produire une nouvelle tentative.

PAR23 — préserver le nom court déjà demandé pour le portail : champ facultatif sous le nom complet dans la création commune ; espaces retirés, maximum 30 caractères ; nom court prioritaire dans l'accueil et le sélecteur, nom complet conservé. Groupe existant sans nom court inchangé ; stockage local via métadonnée de groupe, sauvegarde JSON et publication/import partagé conservent la valeur sans changer le schéma SQL. Fusion vers un groupe existant conserve l'identité du groupe cible.

Précision PAR23 issue de revue, avant correctif : la fusion dans une base vide doit aussi importer le nom court des nouveaux groupes. La fusion vers un groupe déjà présent ne remplace pas son nom court et n'importe aucune métadonnée sensible supplémentaire.

## Mise en œuvre

Le point d'entrée `mobile/lib/main_web.dart` réutilise l'application Flutter : écrans, contrôleurs, repositories et règles sont communs. Les adaptations sont limitées aux frontières de plateforme : SQLite persistant dans le navigateur, transport HTTP, lecture/téléchargement de sauvegardes, photos et shell web. Les photos web sont conservées en données intégrées. La parité du code ne prouve pas à elle seule la compatibilité de chaque navigateur.

Le contrat partagé transmet désormais `is_active` et restitue `active_session_id`. Un second démarrage concurrent est refusé sans bloquer les autres opérations en attente. Les anciens snapshots sans état explicite ne suppriment pas l'état local. Cette parité interappareils exige de mettre à jour le backend et les clients ; un ancien APK ne transmet pas ce nouveau signal.

## Traçabilité

Références relues : design-system, thème, PrimaryButton, création de groupe et ajout initial, nouvelle séance et détail, point financier et finances, service partagé, sauvegardes, navigation principale. Les changements préexistants du mobile et de l'accueil web restent préservés.

### Preuves et portée

- Backend : 71 tests passés, dont cycle de vie partagé et nom court (`parity-backend-final.txt`).
- Portail historique et packaging : 58 tests passés, build statique réussi (`parity-web-regression.txt`). Le portail reste disponible sous `/portal/`, sans migration automatique de ses données vers SQLite Flutter.
- Sauvegardes après revue : 39 tests passés (`parity-short-name-merge-green.txt`). RED réel : nom court absent après fusion dans une base vide (`parity-short-name-merge-red.txt`). Deux bases SQLite distinctes sont nécessaires ; la première fixture partageait à tort la même instance et ne constituait pas une preuve.
- Analyse ciblée des neuf fichiers de plateforme/identité/sauvegarde : aucune anomalie (`parity-analysis-final.txt`).
- Revue indépendante : problèmes de snapshot historique, démarrage concurrent et fusion des noms courts corrigés ; aucun blocage résiduel confirmé lors du dernier passage. Revue par lecture, distincte des tests exécutés.

Les journaux `parity-flutter-final.txt`, `parity-build-final.txt` et `parity-browser-final.txt` contiennent les dernières exécutions de la suite Flutter, de la compilation web et des deux parcours Chrome.

Les captures `parity-captures/before-start-393.png`, `active-393.png` et `restored-393.png` documentent le démarrage explicite et la reprise locale en clair à 393 px. La version sombre a aussi été vue dans le navigateur intégré. Cela ne valide pas toute la matrice PAR19.

Restent à contrôler sur appareils : Safari/iOS, Firefox, clavier, caméra, zones sûres, tous les écrans à 320 px et textes 130/200 %, installation PWA et plusieurs onglets simultanés. Le plugin SQLite web utilise un worker et mérite une recette dédiée sur ces environnements. Les parcours finance/permissions/statistiques reposent sur les mêmes écrans et les tests Flutter ; ils n'ont pas tous été rejoués manuellement dans chaque navigateur.

Configuration Vercel préparée pour `scripts/build-universal-web.sh` et `web/universal-dist` ; compilation locale Windows vérifiée, exécution Linux Vercel et déploiement distant non réalisés. Aucun commit ni push effectué dans ce lot ; les modifications préexistantes restent dans le checkout.
