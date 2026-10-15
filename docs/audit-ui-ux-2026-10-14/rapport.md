# Audit UI/UX Statoo — 14 octobre 2026

## Synthèse

**L’application possède une base visuelle cohérente et des parcours sportifs lisibles, mais sa qualité ne peut pas encore être considérée comme homogène sur les parcours partagés et financiers.** Les risques prioritaires portent sur la protection des données à la restauration, la conservation des saisies financières, l’identification des échéances et la possibilité de vérifier les décisions financières avant confirmation. Le thème clair présente des contrastes mesurés insuffisants sur des informations courantes.

La lecture QA porte sur les conséquences et les transitions ; la lecture UI/UX porte sur l’orientation, la compréhension, la charge de saisie et la cohérence des repères. Les constats ci-dessous distinguent systématiquement **écran**, **code**, **test automatisé** et **reste à tester**. Aucun écran n’est déclaré correct au seul motif que son code paraît correct. Aucune certification WCAG ni validation de mise en production n’est donnée.

**19 constats retenus : 8 majeurs, 10 modérés, 1 mineur ; aucun critique démontré.** Les constats « confirmés par le code » ne sont pas présentés comme reproduits sur appareil. Deux scénarios de concurrence/droits et le clavier financier restent probables en conditions réelles. La fréquence et l’effort proposés sont des estimations d’audit, pas des mesures de télémétrie ni des engagements.

Les défauts de sauvegarde et de restauration sont inclus parce qu’ils déterminent la confiance utilisateur dans les actions de l’interface. Le rapport n’est pas un audit sécurité/backend exhaustif.

## Produit, utilisateurs et règles prises en compte

Statoo remplace des notes et un tableur pour un groupe de football entre amis. Le responsable sportif prépare les présents et les camps, saisit scores/statistiques puis clôture ; les joueurs consultent les résultats, les classements et leurs fiches. Le produit courant ajoute plusieurs groupes, les tournois à trois camps, un MVP mensuel, un trésorier pour cotisations/pénalités/dons/dépenses, et une consultation web. Il faut distinguer les gestionnaires des membres en lecture seule et distinguer enregistrement local, synchronisation et version publiée.

Le cahier des charges initial vise un administrateur sur un téléphone Android, hors ligne, une séance saisie en moins de deux minutes, ouverture sous deux secondes, jusqu’à 50 joueurs/500 séances et cibles de 44 px. La documentation récente élargit ce périmètre aux rôles et au partage ; cet élargissement n’est pas classé comme un défaut en soi. ADMIN ne donne pas automatiquement les droits SG/TR ; tous les membres actifs doivent la cotisation même absents, les avances ne paient pas les pénalités, les dépenses diminuent la caisse et les soldes initiaux doivent être approuvés.

Règles sportives : 3/1/0, points sur séances classées closes, statistiques brutes incluant les amicaux clos, historique préservé par archivage, une séance active par groupe. Le code rend bloquant l’écart buts/score alors que le cahier des charges initial le prévoyait non bloquant ; ce point figure déjà comme arbitrage ouvert dans docs/decisions-and-risks.md et n’est pas compté comme un nouveau bug. L’initialisation classique à 0-0, le tournoi et le MVP sont également distingués des exigences historiques.

Références consultées : README racine/mobile/web, docs/architecture.md, business-rules.md, conventions.md, shared-group-and-finance.md, testing-and-release.md, decisions-and-risks.md, cahier des charges PDF (5 pages, extraction du texte), brief specs/prompt-agent-flutter-statoo.md, thème/composants/router et implémentations des parcours. Les maquettes historiques sous statoo-captures sont inventoriées ; leur comparaison graphique exhaustive n’a pas été effectuée. L’audit juge principalement le produit courant et ne transforme pas leurs anciennes conventions Inter/sombre seul en défauts de Poppins/clair.

## Méthode et périmètre réel

- Application : consultation d’un téléphone Android connecté, modèle retourné `23129RAA4G`, 1080×2400 pixels, densité 440 dpi (largeur logique théorique ~393 dp). Version installée : 1.0.0, code 1, cible Android 36. La version Android de l’OS n’a pas été relevée. Clavier AZERTY visible dans les formulaires joueur ; texte et thème laissés selon les réglages de l’appareil.
- Captures : prises sur appareil en thème clair, d’abord avec un groupe existant à 16 actifs et deux séances le 12 octobre (une close 2-1 et une active 0-0), puis avec le groupe vide JsA trouvé affiché lors de la reprise. Aucune mutation de joueur, score, séance ou mouvement financier n’a été validée par l’audit. La sélection et le tirage de composition sont restés temporaires et ont été abandonnés. Le changement vers JsA n’a pas été effectué par l’audit.
- Portail : source web servie localement sur 127.0.0.1:8087. API synthétique locale 8088, noms/montants/jeton fictifs. Il s’agit d’un test du client web, **pas** d’un test d’intégration de la vraie API, de Neon, de Render ou des permissions du serveur. Les états 401 sont simulés.
- Responsive web : 320×740 et 1280×900 ; largeur initiale étroite également observée. Taille du viewport remise à son réglage initial après contrôle. Tableaux volontairement défilants ; leur simple présence n’est pas un défaut de reflow.
- Lecture de code : routes, écrans, feuilles modales, formulaires et contrôleurs pertinents ; références précises et copies figées dans `sources/`. Les generated/freezed ne constituent pas des preuves d’interface.
- Isolation : aucun test destructif sur données réelles, aucun déploiement, aucun appel à un compte externe. Les tests Flutter utilisent leurs fixtures existantes, le serveur web synthétique n’a pas de base de production.

### Attention : contexte évolutif

Le dépôt contenait déjà des modifications au début de l’audit. Les écrans Finances/Groupe partagé et la branche ont évolué pendant la session, et l’APK a été mis à jour à 11:31:40 d’après Android. Les captures précoces (notamment détail/identités de camps) ne prouvent pas à elles seules l’état du dernier APK. Le code final et l’inventaire Git sont enregistrés dans `source-manifest.json`. L’audit n’a ni appliqué ces modifications applicatives, ni commité, ni compilé ou installé l’APK. Les captures intermédiaires portant un nom de fichier prévu pour un écran différent sont identifiées explicitement dans la matrice ; elles ne sont pas utilisées pour prétendre une couverture inexistante.

## Inventaire des écrans et matrice de couverture

Le router déclare les cinq branches Accueil, Séances, Joueurs, Classement, Stats et les routes racines splash, onboarding, créer-équipe, ajouter-joueurs-initiaux, réglages, joueur, nouvelle-séance, détail-séance, finances, point financier et groupe partagé. La matrice décompose les sous-écrans et modales. **« Code » ne signifie jamais « validé visuellement ».** Les états secondaires non exercés figurent dans la dernière colonne.

| Écran / parcours | Réellement examiné | Preuve / mode | Captures | Restant |
|---|---|---|---|---|
| Démarrage / splash | Écran de démarrage vu ; reprise vers accueil | Code + écran | 17-new-session.png | Démarrage à froid chronométré, échec SQLite/stockage sécurisé, réduction animations |
| Onboarding, 3 pages | Textes, PageView, commandes et animations lus | Code | — | Premier lancement vierge, petit écran/texte 200 %, TalkBack, désactivation animations |
| Création groupe / restauration initiale | Nouveau groupe ouvert, clavier puis formulaire sans clavier et accès sauvegarde observés ; formulaire quitté sans soumission | Code + écran | 45-create-group.png;47-end-home.png | Soumission sur base isolée, premier lancement, restauration sécurisée, erreurs I/O |
| Effectif initial | Ajout en boucle et sortie lus | Code | — | Création complète, doublons et reprise après interruption |
| Sélecteur de groupes | Liste de deux groupes ouverte, actif identifié, accès Nouveau groupe utilisé sans changer le groupe actif | Code + écran | 44-groups.png | Noms longs, >10 groupes, changement effectif et erreurs |
| Accueil | Actif 0-0, MVP, classement, tuiles, pied ; puis groupe vide JsA ; défilement | Code + écran | 03-sessions.png;13-state.png;27-home-lower.png;29-return-home.png;30-home-empty-lower.png | Erreur et chargement réels ; tournoi actif ; deux thèmes |
| Liste Séances | Deux séances, en cours/clôturée ; puis état sans séance dans groupe vide | Code + écran | 04-session-list.png;19-list-current.png;35-sessions-empty.png | Activer chaque filtre, 500 séances, amical filtré, grands textes |
| Nouvelle séance, étape 1 | Date/options, calendrier ouvert puis annulé | Code + écran | 20-new-session.png;21-date-picker.png | Heure, option tournoi, toutes validations et texte 200 % |
| Composition, étape 2 | Aucun présent → 16 sélectionnés → tirage 8/8, défilement, personnalisation visible ; aucune sauvegarde | Code + écran | 22-composition.png;23-composition-selected.png;24-composition-lower.png;25-composition-draw.png | Noms identiques, palettes, changements manuels et 3 camps sur appareil |
| Abandon création | Retour étape 2 → étape 1 → confirmation ; abandon sans écriture de séance | Code + écran | 26-abandon.png | Interruption processus et reprise ; premier écran modifié sans présents |
| Détail séance active | En-tête, score, buteurs vides, camps et liste de joueurs consultés | Code + écran | 02-open.png | Aucun score/stat modifié ; clôture, erreurs, détails bas, hors ligne et révocation |
| Détail clos / brouillon / tournoi | Branches de rendu et actions examinées | Code | — | Écrans réels de chaque état, annulation/réouverture/suppression sur copie |
| Stats joueur en séance / retardataires | Modales, validation, équilibre et sauvegarde examinés | Code | — | Ouverture réelle, champs longs, équipe C, confirm/annuler, effets sur le score |
| Liste Joueurs / archivés / recherche | Liste 16 actifs puis 0 actif consultée ; code recherche/options/archivage lu | Code + écran | 06-players.png;36-players-empty.png | Recherche sans résultat réelle, archivés, noms longs, 50 joueurs, TalkBack |
| Fiche joueur | Synthèse, stats brutes et historique actif/clos consultés | Code + écran | 09-player-detail.png | Chargement partiel/erreur, joueur introuvable, long nom, éligibilité |
| Création / édition joueur | Deux formulaires ouverts avec clavier ; aucun enregistrement | Code + écran | 14-edit-player.png;15-new-player.png | Photo/permissions, doublon, échec I/O, double appui, annulation d’une saisie modifiée |
| Classement | Points avec données ; Points, ratio, buteurs, passeurs, cartons et MVP sans données effectivement ouverts ; règles lues | Code + écran | 07-ranking.png;37-ranking-empty.png;38-ratio-empty.png;39-scorers-empty.png;40-assists-empty.png;41-cards-empty.png;42-mvp-empty.png | Chaque sous-onglet rempli, filtres jaune/rouge, mois, éligibilité réelle, ordre ex æquo mobile/web |
| Statistiques groupe | Totaux, attaque, discipline et début intégrité consultés sur groupe rempli et groupe vide | Code + écran | 08-stats.png;43-stats-empty.png | Bas intégrité, données incohérentes, erreur/retry, texte agrandi |
| Réglages | Haut groupe/sport/finances et bas MVP/apparence/données/À propos consultés ; aucune préférence modifiée | Code + écran | 10-edit-player.png;28-finances.png | Thème sombre réel, édition des paramètres, export/restore et annulation native |
| Finances synthèse / échéances / détails membre | Synthèse sans membre, caisse zéro et feuille des échéances vide consultées ; filtres/tri/calculs lus et tests widgets exécutés | Code + test + écran vide | 31-finances-empty.png;32-periods-empty.png | Synthèse remplie, tri/recherche réelle, détail membre, échéances datées et provisoires ; capture 28 = Réglages |
| Point financier / dépense / pénalité / validation | Chargement, contrôleurs, permissions, listes, modales et sauvegarde examinés | Code | — | Véritable saisie sur jeu isolé ; clavier, brouillon, annulation, correction et rechargement |
| Groupe partagé — rejoindre / partager | Rejoindre et Partager ouverts, défilement des champs, aucune soumission ; tests étroits clair/sombre exécutés | Code + test + écran | 33-shared-connection.png;34-share-form.png | Connexion mobile réelle, hors ligne, champs invalides, serveur déplié et erreurs 401/503 |
| Groupe partagé — comptes / rôles / arbitrage / ouverture / transfert | Chaque branche et modale examinée ; visibilité ADMIN/MEMBER testée par widgets existants | Code + test | — | Deux appareils/rôles réels ; comparaison de conflits ; rotation, révocation et jeton expiré |
| Portail — connexion | Formulaire vide bloqué par validation native ; connexion fictive ; déconnexion fictive | Code + navigateur | — | Identifiants invalides sur vraie API, erreur JSON/HTML, lenteur, mot de passe long |
| Portail — séances | Tournoi personnalisé synthétique affiché | Code + navigateur | web-01-tournament.png | Liste vide/volumineuse, séance classique/amicale et fuseaux horaires réels |
| Portail — classement | Tableau à trois membres ; calcul ex æquo exécuté séparément | Code + navigateur + calcul | web-02-ranking.png;web-06-320.png | Tableau sans membre, noms très longs, 50 membres, comparaison complète mobile |
| Portail — finances | Caisse zéro, trois soldes, section points vide ; 401 simulé | Code + navigateur | web-03-finances-empty.png;web-04-expired.png | Points publiés détaillés, grands montants, connexions réelles, erreur lente |
| Responsive web / clavier | 320×740, 1280×900, viewport initial étroit ; Tab Classement → Finances ; pas de débordement horizontal global à 320, tableau défilant | Navigateur + DOM | web-05-desktop.png;web-06-320.png | Zoom 200/400 %, lecteur d’écran, navigation complète clavier/tableaux, Safari et Firefox |

## Résultats des vérifications automatisées

- `node --test web/tests/summary.test.mjs` : **1 test réussi**. Il ne couvrait pas le départage par victoires ; le scénario autonome `check-ranking.mjs` expose l’écart UX09.
- `flutter test test/features/sessions/session_close_test.dart test/features/settings/backup_service_test.dart test/features/shared/shared_group_screen_test.dart test/features/finance/finances_screen_test.dart` : **23 réussites, 8 échecs**, code de sortie 1. Les huit échecs listés concernent les tests de contrôleur du fichier session_close_test, avec `databaseFactory not initialized` lors de SharedService.requireWrite. Les contrôles purs de clôture passent ; les autres fichiers ont contribué aux réussites, dont les cas de formulaires partagés étroits et finances clair/sombre. Le harnais de contrôle des droits n’est donc pas validé par cette commande ; ne pas interpréter ces échecs comme huit bugs UI reproduits.
- Aucun test ajouté à l’application, aucun correctif appliqué pour faire passer cette commande. Aucun benchmark de démarrage ou mesure de saisie sous deux minutes. Les observations de réactivité à la main ne sont pas un profil de performance.

## Constats détaillés, classés par sévérité

Sévérité critique = blocage généralisé/perte grave démontrée sans récupération ; majeure = risque métier fort ou parcours principal dégradé ; modérée = difficulté réelle avec contournement ; mineure = défaut local de faible impact. La gravité n’est pas augmentée pour une simple préférence esthétique.

### UX01 — La restauration depuis « Nouveau groupe » remplace toute la base sans confirmation

**Écran/parcours :** Réglages → Nouveau / sélecteur de groupes → Créer un groupe → J’ai déjà une sauvegarde  
**Catégorie :** bug fonctionnel · **Sévérité : majeure** — Une action présentée dans un parcours d’ajout peut effacer tous les groupes existants ; conséquence grave, déclenchement occasionnel.  
**Statut :** confirmé par le code ; opération destructive non exécutée · **Confiance :** élevé.

**Conditions et reproduction :** Avec au moins un groupe existant, ouvrir la création d’un autre groupe, choisir la restauration puis sélectionner une sauvegarde valide. Ne pas effectuer ce scénario sur une base réelle.

**Observé :** Après sélection du fichier, _restoreFromBackup appelle directement restoreBackup(merge: false). Le service supprime participations, séances, joueurs, meta et groupes. La confirmation de remplacement proposée dans Réglages n’est pas utilisée ici.

**Attendu :** Présenter le périmètre exact du remplacement et laisser annuler avant toute écriture ; dans un parcours d’ajout, proposer une importation isolée si elle est supportée.

**Impact :** Perte possible des données locales d’autres groupes, alors que l’utilisateur pense ajouter un groupe.

**Preuve :** [mobile/lib/features/team/presentation/create_team_screen.dart:73](sources/mobile/lib/features/team/presentation/create_team_screen.dart.html#L73) — ligne 73, `restoreBackup(payload, merge: false)` ; [mobile/lib/features/settings/data/backup_service.dart:136](sources/mobile/lib/features/settings/data/backup_service.dart.html#L136) — ligne 136, `await txn.delete('teams')`. Les sources figées HTML permettent d’ouvrir la ligne citée ; les copies `.txt` conservent également le fichier complet.

**Recommandation applicable :** Réutiliser une confirmation de restauration commune ; distinguer « Importer un groupe » et « Remplacer toutes les données de cet appareil ». Proposer une sauvegarde préalable.

**Critère d’acceptation :** Avec deux groupes locaux, annuler conserve exactement les deux groupes et toutes leurs données. Le remplacement exige une confirmation explicite nommant les groupes affectés.

**Exposition / effort estimé :** occasionnelle, impact très fort / moyen.

### UX02 — Le point financier perd les montants non validés au retour arrière

**Écran/parcours :** Point financier → encaissements / dépenses  
**Catégorie :** problème UX · **Sévérité : majeure** — Une saisie répétitive et sensible peut être perdue en un geste ; aucun brouillon ni avertissement dans ce parcours.  
**Statut :** confirmé par le code ; perte non provoquée sur téléphone · **Confiance :** élevé.

**Conditions et reproduction :** Sur une échéance de test autorisée, saisir plusieurs versements et une dépense, revenir à la liste sans valider puis rouvrir le point.

**Observé :** Les contrôleurs et listes restent dans le State ; dispose les détruit. L’écriture métier passe seulement par _save. Aucun PopScope ni sauvegarde du brouillon ne protège la sortie.

**Attendu :** Conserver un brouillon local identifié ou demander « Conserver / Abandonner / Continuer » lors d’une sortie avec modifications.

**Impact :** Ressaisie de tous les versements, risque de reconstitution erronée et perte de confiance au bord du terrain.

**Preuve :** [mobile/lib/features/finance/presentation/financial_point_screen.dart:89](sources/mobile/lib/features/finance/presentation/financial_point_screen.dart.html#L89) — ligne 89, `void dispose()` ; [mobile/lib/features/finance/presentation/financial_point_screen.dart:119](sources/mobile/lib/features/finance/presentation/financial_point_screen.dart.html#L119) — ligne 119, `Future<void> _save()` ; comparaison avec [mobile/lib/features/sessions/presentation/new_session_screen.dart:280](sources/mobile/lib/features/sessions/presentation/new_session_screen.dart.html#L280) — ligne 280, `return PopScope(`. Les sources figées HTML permettent d’ouvrir la ligne citée ; les copies `.txt` conservent également le fichier complet.

**Recommandation applicable :** Suivre un état modifié, persister un brouillon local indépendant de la validation et le restaurer ; protéger retour système, flèche, fermeture et reprise.

**Critère d’acceptation :** Après saisie de trois membres et d’une dépense, retour puis réouverture conserve le brouillon ou demande explicitement son abandon. Aucune publication n’a lieu avant confirmation.

**Exposition / effort estimé :** chaque saisie interrompue / moyen.

### UX03 — Deux séances du même jour partagent par défaut le même point financier

**Écran/parcours :** Création locale de séances → Finances  
**Catégorie :** bug fonctionnel · **Sévérité : majeure** — La clé financière peut confondre deux échéances réelles et leurs cotisations ; le cas de deux séances le même jour existe dans les données affichées.  
**Statut :** confirmé par lecture des clés ; rapprochement non exécuté sur les données du téléphone · **Confiance :** élevé.

**Conditions et reproduction :** Créer dans un groupe local deux séances à des heures différentes le même jour sans référence explicite, puis ouvrir leurs points financiers successivement.

**Observé :** Le champ de référence n’est présenté que si sharedService.connected. canonical attribue sinon « AAAA-MM-JJ-1 » aux deux séances et réutilise l’alias de la première.

**Attendu :** Chaque séance distincte doit avoir une référence distincte par défaut, sauf rapprochement volontaire et expliqué avec une échéance existante.

**Impact :** Le second point peut afficher ou remplacer les versements du premier ; la dette calculée ne représente pas nécessairement deux échéances.

**Preuve :** [mobile/lib/features/sessions/presentation/new_session_screen.dart:308](sources/mobile/lib/features/sessions/presentation/new_session_screen.dart.html#L308) — ligne 308, `ref.watch(sharedServiceProvider).connected` ; [mobile/lib/features/finance/data/finance_repository.dart:82](sources/mobile/lib/features/finance/data/finance_repository.dart.html#L82) — ligne 82, `occurrence = '${playedAt.substring(0, 10)}-1'` ; [mobile/lib/features/finance/data/finance_repository.dart:93](sources/mobile/lib/features/finance/data/finance_repository.dart.html#L93) — ligne 93, `if (alias.isNotEmpty) return alias.single['value']! as String`. Les sources figées HTML permettent d’ouvrir la ligne citée ; les copies `.txt` conservent également le fichier complet.

**Recommandation applicable :** Générer le prochain numéro libre dans une transaction ; rendre la référence visible et modifiable en local et en partagé ; demander explicitement tout rattachement à une échéance déjà existante.

**Critère d’acceptation :** Deux séances le même jour produisent -1 et -2, deux points et deux cotisations. Un rattachement intentionnel est explicite, stable après sauvegarde/restauration.

**Exposition / effort estimé :** plusieurs séances dans une journée / moyen.

### UX04 — L’arbitre ne peut pas comparer les différences décisives entre versions

**Écran/parcours :** Groupe partagé → Arbitrages  
**Catégorie :** problème UX · **Sévérité : majeure** — Une décision financière ou sportive durable peut être prise sur des versions visuellement indiscernables.  
**Statut :** confirmé par le code ; conflit réel non soumis · **Confiance :** élevé.

**Conditions et reproduction :** Préparer deux versions de test ayant la même date et le même total de versements, mais des dépenses ou des bénéficiaires différents ; ouvrir le choix de version.

**Observé :** _arbitrate ne présente que _summary : date/score pour le sport, date/somme des versements membres pour la finance. Dépenses, dons, détail des membres, auteur et horodatage de la version ne sont pas affichés. Les victoires du tournoi ne sont pas résumées.

**Attendu :** Permettre une comparaison factuelle de ce qui sera retenu : auteur, date de saisie, montants par membre, dépenses/dons, score/victoires et statistiques modifiées.

**Impact :** Le président peut écarter la bonne version sans disposer des éléments pour décider ; le motif obligatoire ne compense pas cette absence.

**Preuve :** [mobile/lib/features/shared/presentation/shared_group_screen.dart:242](sources/mobile/lib/features/shared/presentation/shared_group_screen.dart.html#L242) — ligne 242, `Future<void> _arbitrate(` ; [mobile/lib/features/shared/presentation/shared_group_screen.dart:333](sources/mobile/lib/features/shared/presentation/shared_group_screen.dart.html#L333) — ligne 333, `String _summary(`. Les sources figées HTML permettent d’ouvrir la ligne citée ; les copies `.txt` conservent également le fichier complet.

**Recommandation applicable :** Ajouter un écran de comparaison avant sélection : version publiée face à chaque candidate, différences surlignées, auteur et dates lisibles ; conserver le motif et une dernière confirmation du résultat choisi.

**Critère d’acceptation :** Deux versions à total reçu identique mais dépenses différentes sont distinguables ; deux tournois de même date affichent leurs victoires ; la décision peut être expliquée sans consulter la base.

**Exposition / effort estimé :** chaque conflit / important.

### UX05 — Les soldes initiaux sont approuvés sans présenter les montants à vérifier

**Écran/parcours :** Groupe partagé → Situation financière de départ → Approuver  
**Catégorie :** problème UX · **Sévérité : majeure** — L’action initialise la caisse et les dettes du groupe ; la vérification préalable doit porter sur des chiffres visibles.  
**Statut :** confirmé par le code ; approbation non exécutée · **Confiance :** élevé.

**Conditions et reproduction :** Avec un compte PDT/VP et une proposition d’ouverture de test, ouvrir Groupe partagé et sélectionner « Approuver les soldes initiaux ». 

**Observé :** La ligne promet « Vérifier la situation soumise par le trésorier », mais son onTap appelle directement POST /opening/approve puis synchronize. Aucun écran de proposition ni confirmation ne montre caisse, date ou soldes individuels.

**Attendu :** Afficher et faire confirmer la proposition exacte avant approbation.

**Impact :** Validation aveugle d’erreurs d’ouverture qui faussent tous les soldes suivants.

**Preuve :** [mobile/lib/features/shared/presentation/shared_group_screen.dart:1181](sources/mobile/lib/features/shared/presentation/shared_group_screen.dart.html#L1181) — ligne 1181, `title: 'Approuver les soldes initiaux'` ; [mobile/lib/features/shared/presentation/shared_group_screen.dart:1188](sources/mobile/lib/features/shared/presentation/shared_group_screen.dart.html#L1188) — ligne 1188, `'/groups/${service.groupId}/opening/approve'`. Les sources figées HTML permettent d’ouvrir la ligne citée ; les copies `.txt` conservent également le fichier complet.

**Recommandation applicable :** Ouvrir un récapitulatif consultable de la caisse, de la date de départ et de chaque solde ; ajouter auteur, date et actions Approuver / Revenir, avec gestion des erreurs.

**Critère d’acceptation :** Aucun POST d’approbation avant le récapitulatif et une confirmation explicite. Les chiffres confirmés sont ceux de la révision approuvée.

**Exposition / effort estimé :** une fois par groupe, impact durable / moyen.

### UX06 — Les membres en lecture seule voient des commandes sportives et joueurs actives

**Écran/parcours :** Accueil, Joueurs, fiche joueur, création et détail séance  
**Catégorie :** problème UX · **Sévérité : majeure** — Plusieurs parcours de saisie peuvent être parcourus avant un refus ; le contrat « consultation » n’est pas représenté dans l’UI.  
**Statut :** probable en bout en bout ; discordance UI/contrôleur confirmée par le code · **Confiance :** élevé.

**Conditions et reproduction :** Se connecter avec MEMBER/CENSOR sans ADMIN ni SG/SGA, puis ouvrir Nouveau joueur, Modifier ou Nouvelle séance et tenter d’enregistrer sur des données de test.

**Observé :** Les commandes sont présentées sans consulter canWrite dans ces écrans ; les contrôleurs vérifient requireWrite. NewPlayerBottomSheet._submit n’intercepte pas ces exceptions ; l’édition utilise finally sans catch. Le formulaire peut rester ouvert sans message utilisateur exploitable.

**Attendu :** Masquer les mutations interdites ou expliquer le rôle requis avant toute saisie ; traiter le refus final même si les droits changent entre-temps.

**Impact :** Saisie inutile, impression de bouton cassé ; confusion entre consultation et gestion. Le contrôle côté données existe : aucun contournement de droits n’est affirmé.

**Preuve :** [mobile/lib/features/players/presentation/players_screen.dart:155](sources/mobile/lib/features/players/presentation/players_screen.dart.html#L155) — ligne 155, `floatingActionButton: FloatingActionButton(` ; [mobile/lib/features/players/presentation/new_player_bottom_sheet.dart:45](sources/mobile/lib/features/players/presentation/new_player_bottom_sheet.dart.html#L45) — ligne 45, `Future<void> _submit(` ; [mobile/lib/features/players/application/players_provider.dart:30](sources/mobile/lib/features/players/application/players_provider.dart.html#L30) — ligne 30, `requireWrite(activeTeamId, 'members')` ; [mobile/lib/features/sessions/application/sessions_provider.dart:156](sources/mobile/lib/features/sessions/application/sessions_provider.dart.html#L156) — ligne 156, `requireWrite(teamId, 'sport')`. Les sources figées HTML permettent d’ouvrir la ligne citée ; les copies `.txt` conservent également le fichier complet.

**Recommandation applicable :** Appliquer une même capacité métier à l’affichage et à l’exécution ; traiter les erreurs de droit dans les formulaires, préserver la saisie et proposer le contact du rôle approprié.

**Critère d’acceptation :** Matrice MEMBER/CENSOR/ADMIN/SG/TR : chaque compte voit uniquement ses mutations autorisées. Une révocation pendant la saisie déclenche un message clair et conserve les champs.

**Exposition / effort estimé :** tous les membres de consultation / moyen.

### UX07 — Une restauration rétrograde les tournois clôturés en brouillons

**Écran/parcours :** Sauvegarde JSON → restauration  
**Catégorie :** bug fonctionnel · **Sévérité : majeure** — La restauration d’un tournoi valide change son état et peut le retirer du classement.  
**Statut :** confirmé par le code ; restauration réelle non exécutée · **Confiance :** élevé.

**Conditions et reproduction :** Sur une copie de test, exporter un tournoi CLOSED avec résultat/victoires mais sans score_a/score_b, puis restaurer.

**Observé :** _withValidStatus considère toute séance sans scores A/B comme non renseignée, sans exception TOURNAMENT_3, puis remplace CLOSED par DRAFT. La création des tournois laisse justement ces scores à null.

**Attendu :** Valider le statut selon le type : score/résultat classique, victoires/résultat tournoi ; conserver les tournois valides.

**Impact :** Classements incomplets après récupération ; l’utilisateur doit détecter et reprendre des séances qu’il pensait archivées.

**Preuve :** [mobile/lib/features/settings/data/backup_service.dart:367](sources/mobile/lib/features/settings/data/backup_service.dart.html#L367) — ligne 367, `final unscored =` ; [mobile/lib/features/sessions/application/sessions_provider.dart:174](sources/mobile/lib/features/sessions/application/sessions_provider.dart.html#L174) — ligne 174, `scoreA: isTournament ? null : 0`. Les sources figées HTML permettent d’ouvrir la ligne citée ; les copies `.txt` conservent également le fichier complet.

**Recommandation applicable :** Distinguer les règles de normalisation classique et tournoi dans l’import ; annoncer les anomalies corrigées avant validation.

**Critère d’acceptation :** Export → restauration d’un tournoi valide conserve CLOSED, équipes, victoires et contributions au classement. Les classiques réellement incomplets sont signalés.

**Exposition / effort estimé :** chaque restauration contenant un tournoi / faible à moyen.

### UX08 — Le thème clair contient plusieurs contrastes insuffisants

**Écran/parcours :** Bandeaux Joueurs/Séances, liens verts et actions primaires  
**Catégorie :** accessibilité · **Sévérité : majeure** — Défaut fréquent sur les parcours principaux ; les sous-titres indiquant le groupe deviennent difficiles à lire.  
**Statut :** confirmé à l’écran et par calcul des couleurs opaques · **Confiance :** élevé.

**Conditions et reproduction :** En thème clair, ouvrir Séances ou Joueurs et lire le groupe sous le titre ; comparer les boutons primaires et les textes verts sur carte blanche.

**Observé :** foreground400 #475569 sur header #15803D : 1,51:1. primary400 #16A34A sur blanc : 3,30:1 et sur fond #E9EEF3 : 2,82:1. PrimaryButton utilise #0B0F14 sur #15803D : 3,83:1 pour un libellé 16 logical px gras. Dans Nouveau groupe, la flèche retour blanche est aussi très peu visible sur le fond gris clair (capture 47) : le thème fixe iconTheme sur onHeader même pour une barre transparente. Les commentaires de tokens ne garantissent pas les associations réelles.

**Attendu :** Les textes ordinaires visés atteignent 4,5:1 ; vérifier aussi la taille effective avant d’appliquer le seuil du grand texte. Les sous-titres de bandeau utilisent onHeader.

**Impact :** Lecture difficile au soleil, basse vision et perte d’orientation entre groupes.

**Preuve :** [Joueurs](06-players.png) ; [Séances](19-list-current.png) ; [mobile/lib/core/theme/app_colors.dart:192](sources/mobile/lib/core/theme/app_colors.dart.html#L192) — ligne 192, `static const AppColorsExtension light` ; [mobile/lib/core/widgets/primary_button.dart:22](sources/mobile/lib/core/widgets/primary_button.dart.html#L22) — ligne 22, `foregroundColor: AppColors.onPrimaryDark`. Les sources figées HTML permettent d’ouvrir la ligne citée ; les copies `.txt` conservent également le fichier complet.

**Recommandation applicable :** Définir des paires de tokens par usage ; utiliser onHeader pour tout le bandeau clair, un vert plus sombre pour les petits liens et un texte contrasté pour le bouton clair. Mesurer les états actifs et désactivés séparément.

**Critère d’acceptation :** Mesure ≥4,5:1 pour les sous-titres 14 px, liens 12–16 px et libellés concernés ; relire clair/sombre sur appareil. Référence WCAG 1.4.3, sans certification globale.

**Exposition / effort estimé :** chaque écran clair concerné / faible.

### UX09 — Le portail départage les ex æquo différemment du mobile

**Écran/parcours :** Portail → Classement / mobile → Points  
**Catégorie :** bug fonctionnel · **Sévérité : modérée** — Les points restent corrects dans le cas testé, mais l’ordre et donc la place diffèrent pour un même groupe.  
**Statut :** confirmé par exécution du calcul web et lecture de l’ordre SQL mobile · **Confiance :** élevé.

**Conditions et reproduction :** Jeu synthétique : Alice a une victoire et une défaite (3 points, 2 matchs) ; Benoît a trois nuls (3 points, 3 matchs). Exécuter node docs/audit-ui-ux-2026-10-14/check-ranking.mjs.

**Observé :** Le web classe Benoît devant Alice par nombre de matchs. Le SQL mobile départage d’abord par victoires, puis matchs, puis nom et place Alice devant.

**Attendu :** Appliquer le même ordre de départage documenté sur toutes les consultations.

**Impact :** Classement contestable selon l’appareil utilisé, surtout en cas d’ex æquo fréquents.

**Preuve :** [web/summary.mjs:18](sources/web/summary.mjs.html#L18) — ligne 18, `b.points-a.points || b.matches-a.matches` ; [mobile/lib/core/data/app_database.dart:384](sources/mobile/lib/core/data/app_database.dart.html#L384) — ligne 384, `ORDER BY points DESC, wins DESC, matches_played DESC` ; [reproduction autonome](check-ranking.mjs). Les sources figées HTML permettent d’ouvrir la ligne citée ; les copies `.txt` conservent également le fichier complet.

**Recommandation applicable :** Calculer les victoires dans le résumé web et harmoniser le comparateur avec le mobile ; exposer la règle de départage au lecteur.

**Critère d’acceptation :** Le jeu de reproduction et des égalités successives points/victoires/matchs/nom produisent exactement le même ordre sur les deux clients.

**Exposition / effort estimé :** chaque ex æquo concerné / faible.

### UX10 — Le clavier risque de masquer les champs du point financier

**Écran/parcours :** Point financier → encaissements  
**Catégorie :** problème UX · **Sévérité : modérée** — Saisie centrale au trésorier ; risque de masquer les dernières lignes et le récapitulatif pendant la saisie.  
**Statut :** probable ; non testé avec montants sur téléphone · **Confiance :** moyen à élevé.

**Conditions et reproduction :** Sur un point de test, afficher un membre en bas de liste, saisir la cotisation avec le clavier numérique puis tenter de passer au champ pénalité et de valider sans fermer manuellement le clavier.

**Observé :** Le Scaffold désactive resizeToAvoidBottomInset ; les listes n’ajoutent pas de marge viewInsets.bottom. SafeArea(maintainBottomViewPadding: true) ne réserve pas la hauteur du clavier.

**Attendu :** Champ focalisé, montant, contexte du membre et commande suivante restent visibles et accessibles.

**Impact :** Erreurs de ligne, fermeture répétée du clavier et ralentissement de la tournée d’encaissement.

**Preuve :** [mobile/lib/features/finance/presentation/financial_point_screen.dart:328](sources/mobile/lib/features/finance/presentation/financial_point_screen.dart.html#L328) — ligne 328, `resizeToAvoidBottomInset: false` ; [mobile/lib/features/finance/presentation/financial_point_screen.dart:455](sources/mobile/lib/features/finance/presentation/financial_point_screen.dart.html#L455) — ligne 455, `Widget _receipts(bool writable)`. Les sources figées HTML permettent d’ouvrir la ligne citée ; les copies `.txt` conservent également le fichier complet.

**Recommandation applicable :** Laisser redimensionner le Scaffold ou ajouter un inset clavier explicite et un scroll vers le champ focalisé ; proposer Suivant sur les champs montants.

**Critère d’acceptation :** À 360×640 et avec clavier numérique, saisir les deux montants du dernier membre sans champ occulté ; refaire avec texte à 200 %. WCAG 1.4.10 et 2.4.11 à vérifier.

**Exposition / effort estimé :** chaque saisie au clavier / faible à moyen.

### UX11 — Plusieurs dialogues se ferment en silence avec une saisie invalide

**Écran/parcours :** Ajouter dépense/don, comptes, transfert, motif d’arbitrage  
**Catégorie :** problème UX · **Sévérité : modérée** — L’utilisateur perd le contexte de correction et n’a aucune explication après son action.  
**Statut :** confirmé par le code ; soumissions invalides non réalisées sur serveur · **Confiance :** élevé.

**Conditions et reproduction :** Dans un jeu de test : ajouter une dépense sans motif ou avec zéro ; ou transférer sans motif / sans destinataire ; ou créer un gestionnaire sans membre.

**Observé :** Les actions ferment la modale avec true avant validation. Le code ne poursuit que si les valeurs sont présentes/positives ; sinon rien ne se passe. Le motif de correction financier est rejeté plus tard par le repository, après fermeture du récapitulatif.

**Attendu :** Garder la modale ouverte, indiquer le champ en erreur et déplacer le focus sur ce champ.

**Impact :** Ressaisie, impression d’action réussie ou de bouton inopérant ; difficultés accrues au lecteur d’écran.

**Preuve :** [mobile/lib/features/finance/presentation/financial_point_screen.dart:208](sources/mobile/lib/features/finance/presentation/financial_point_screen.dart.html#L208) — ligne 208, `Future<void> _addMovement(` ; [mobile/lib/features/shared/presentation/shared_group_screen.dart:591](sources/mobile/lib/features/shared/presentation/shared_group_screen.dart.html#L591) — ligne 591, `if (accepted == true && target != null && explanation.isNotEmpty)` ; [mobile/lib/features/shared/presentation/shared_group_screen.dart:229](sources/mobile/lib/features/shared/presentation/shared_group_screen.dart.html#L229) — ligne 229, `if (result == true && member != null)`. Les sources figées HTML permettent d’ouvrir la ligne citée ; les copies `.txt` conservent également le fichier complet.

**Recommandation applicable :** Employer Form/TextFormField avec validation avant Navigator.pop ; conserver les saisies après refus serveur et traduire les erreurs techniques en étapes correctives.

**Critère d’acceptation :** Chaque formulaire invalide reste ouvert, annonce son erreur et conserve ses champs ; aucun appel réseau ni écriture tant que la validation échoue. Références WCAG 3.3.1/3.3.2.

**Exposition / effort estimé :** erreurs de première saisie / moyen.

### UX12 — La création de joueur ne verrouille pas les soumissions concurrentes

**Écran/parcours :** Nouveau joueur → Créer ou bouton +  
**Catégorie :** bug fonctionnel · **Sévérité : modérée** — Un double appui peut créer des doublons ou une erreur de clé pendant l’attente ; risque dépendant du timing.  
**Statut :** probable ; absence de verrou confirmée par le code · **Confiance :** élevé sur la cause, moyen sur la reproduction.

**Conditions et reproduction :** Avec un nom unique de test et une écriture ralentie, appuyer deux fois rapidement sur Créer, ou combiner la touche clavier de soumission et le bouton +.

**Observé :** _submit attend isNameTaken puis addPlayer sans état isSubmitting ni garde de réentrée. Les boutons restent actifs. L’unicité du nom n’est pas une contrainte SQLite ; les identifiants utilisent les millisecondes.

**Attendu :** Une seule création, un indicateur immédiat et une erreur exploitable si l’écriture échoue.

**Impact :** Doublons d’effectif, sélection erronée aux séances ou action perçue comme bloquée.

**Preuve :** [mobile/lib/features/players/presentation/new_player_bottom_sheet.dart:45](sources/mobile/lib/features/players/presentation/new_player_bottom_sheet.dart.html#L45) — ligne 45, `Future<void> _submit(` ; [mobile/lib/features/players/data/players_repository.dart:166](sources/mobile/lib/features/players/data/players_repository.dart.html#L166) — ligne 166, `id: 'p_${now.millisecondsSinceEpoch}'`. Les sources figées HTML permettent d’ouvrir la ligne citée ; les copies `.txt` conservent également le fichier complet.

**Recommandation applicable :** Verrouiller dès l’entrée de _submit et libérer dans finally ; désactiver toutes les voies de soumission, gérer l’erreur sans fermer ; garantir l’unicité métier au niveau transactionnel.

**Critère d’acceptation :** Dix activations rapides et validation clavier simultanée créent exactement un joueur ; une erreur simulée conserve les champs et permet de réessayer.

**Exposition / effort estimé :** double appui / stockage lent / faible à moyen.

### UX13 — L’identité d’une équipe change entre résumé et détail

**Écran/parcours :** Accueil / liste Séances / détail / historique joueur  
**Catégorie :** défaut visuel · **Sévérité : modérée** — Les couleurs et noms servent à repérer les camps ; leur changement peut faire attribuer une action au mauvais camp.  
**Statut :** confirmé à l’écran ; omission des personnalisations confirmée par le code · **Confiance :** élevé.

**Conditions et reproduction :** Comparer la séance du 12 octobre 14h57 à l’accueil et dans son détail ; répéter avec une séance de test aux noms/couleurs personnalisés.

**Observé :** La capture initiale montre A orange/B verte dans le détail et A bleue/B orange à l’accueil/liste. Le détail lit session.teamName/teamColor ; l’accueil écrit Équipe A/B et couleurs fixes. Le résumé classique ne propage pas l’identité personnalisée.

**Attendu :** Même nom, couleur et repère A/B sur toutes les représentations d’une séance.

**Impact :** Effort de vérification supplémentaire ; confusion de camp pendant la saisie. Les lettres demeurent présentes : l’information n’est pas uniquement chromatique.

**Preuve :** [détail initial](02-open.png) ; [accueil initial](03-sessions.png) ; [mobile/lib/features/home/presentation/home_screen.dart:163](sources/mobile/lib/features/home/presentation/home_screen.dart.html#L163) — ligne 163, `'Équipe A'` ; [mobile/lib/features/sessions/presentation/session_team_colors.dart:10](sources/mobile/lib/features/sessions/presentation/session_team_colors.dart.html#L10) — ligne 10, `final custom = teamColors[teamKey(team)]`. Les sources figées HTML permettent d’ouvrir la ligne citée ; les copies `.txt` conservent également le fichier complet.

**Recommandation applicable :** Réutiliser un composant d’identité de camp basé sur la séance pour les cartes, l’accueil et l’historique. Ne pas comparer les couleurs d’un joueur aux couleurs de son camp.

**Critère d’acceptation :** Une séance aux camps personnalisés conserve ses noms/couleurs dans accueil, liste, détail et historique ; vérifier les deux thèmes et trois camps. Revalider sur l’APK courant, les premières captures précèdent une mise à jour.

**Exposition / effort estimé :** chaque navigation résumé/détail / moyen.

### UX14 — Une photo locale est traitée comme image réseau dans la composition

**Écran/parcours :** Nouveau joueur → photo → création séance / retardataires  
**Catégorie :** bug fonctionnel · **Sévérité : modérée** — Une fonction proposée à la création ne se retrouve pas de façon fiable dans les parcours qui suivent.  
**Statut :** confirmé par le code ; photo non ajoutée sur l’appareil · **Confiance :** élevé.

**Conditions et reproduction :** Créer un joueur de test avec une photo de galerie puis ouvrir sa ligne dans la composition et l’ajout tardif.

**Observé :** La création conserve image.path, un chemin local. Les deux feuilles de composition construisent NetworkImage(avatarUrl). La liste et la fiche utilisent des initiales sans exploiter cette photo ; la sauvegarde conserve le chemin sans embarquer le fichier.

**Attendu :** Afficher la photo locale via un fournisseur de fichier, la conserver dans un répertoire durable et prévoir les initiales si elle manque.

**Impact :** Photo absente ou erreur de chargement, effort de personnalisation perdu ; sur un autre appareil le chemin ne désigne pas le fichier original.

**Preuve :** [mobile/lib/features/players/presentation/new_player_bottom_sheet.dart:60](sources/mobile/lib/features/players/presentation/new_player_bottom_sheet.dart.html#L60) — ligne 60, `avatarUrl: _imageFile?.path` ; [mobile/lib/features/sessions/presentation/new_session_screen.dart:1056](sources/mobile/lib/features/sessions/presentation/new_session_screen.dart.html#L1056) — ligne 1056, `NetworkImage(player.avatarUrl!)` ; [mobile/lib/features/sessions/presentation/add_late_players_bottom_sheet.dart:599](sources/mobile/lib/features/sessions/presentation/add_late_players_bottom_sheet.dart.html#L599) — ligne 599, `NetworkImage(player.avatarUrl!)`. Les sources figées HTML permettent d’ouvrir la ligne citée ; les copies `.txt` conservent également le fichier complet.

**Recommandation applicable :** Centraliser PlayerAvatar avec résolution locale/distante et repli ; décider et annoncer si les photos font partie des sauvegardes.

**Critère d’acceptation :** Photo visible après relance, composition et ajout tardif ; fichier manquant → initiales sans exception ; restauration sur autre appareil conforme au périmètre annoncé.

**Exposition / effort estimé :** joueurs avec photo / moyen.

### UX15 — La sélection des sections n’est pas annoncée de façon cohérente

**Écran/parcours :** Portail → navigation ; mobile → filtres et sélecteurs personnalisés  
**Catégorie :** accessibilité · **Sévérité : modérée** — La personne utilisant une technologie d’assistance doit savoir quelle vue est sélectionnée sans inférer uniquement de la couleur.  
**Statut :** confirmé dans le DOM web ; comportement TalkBack mobile à vérifier · **Confiance :** élevé pour le web, moyen pour le mobile.

**Conditions et reproduction :** Activer Classement puis Finances au clavier dans le portail et inspecter l’arbre d’accessibilité ; sur mobile tester les filtres Séances et Championnat/MVP avec TalkBack.

**Observé :** Les boutons web ne portent ni aria-current, aria-pressed ni état de tab sélectionné ; seul .selected change. Les filtres Séances utilisent GestureDetector sans Semantics(selected), et le sélecteur Championnat/MVP un InkWell personnalisé. Un bouton clavier web reste atteignable : aucune impossibilité globale de navigation n’est affirmée.

**Attendu :** Nom, rôle et état sélectionné sont annoncés ; focus visible et ordre prévisible ; action suivante disponible au clavier quand applicable.

**Impact :** Orientation et confirmation de changement plus difficiles pour les personnes aveugles ou utilisant le clavier.

**Preuve :** [web/index.html:21](sources/web/index.html.html#L21) — ligne 21, `data-tab="sessions"` ; [web/app.mjs:78](sources/web/app.mjs.html#L78) — ligne 78, `b.classList.toggle('selected'` ; [mobile/lib/features/sessions/presentation/sessions_screen.dart:124](sources/mobile/lib/features/sessions/presentation/sessions_screen.dart.html#L124) — ligne 124, `return GestureDetector(`. Les sources figées HTML permettent d’ouvrir la ligne citée ; les copies `.txt` conservent également le fichier complet.

**Recommandation applicable :** Choisir une navigation à aria-current ou de vrais onglets avec aria-selected et relations panneau ; utiliser FilterChip/SegmentedButton ou ajouter sémantique et focus équivalents sur mobile.

**Critère d’acceptation :** Lecteur d’écran annonce « Finances, sélectionné » après activation ; un seul état actif ; parcours complet au clavier puis TalkBack réel. Références WCAG 4.1.2 et 2.1.1, sans certification.

**Exposition / effort estimé :** navigation assistée / moyen.

### UX16 — L’expiration laisse des données anciennes visibles sans parcours de reconnexion

**Écran/parcours :** Portail → Actualiser → réponse 401  
**Catégorie :** problème UX · **Sévérité : modérée** — Le message existe, mais la récupération demande une déconnexion manuelle et l’ancien contenu reste affiché.  
**Statut :** confirmé dans le navigateur avec API synthétique · **Confiance :** élevé.

**Conditions et reproduction :** Se connecter au serveur de test, simuler une réponse 401 à /groups/audit, puis Actualiser.

**Observé :** Le tableau de bord et sa précédente heure d’actualisation restent visibles ; « Connexion expirée » apparaît en bas du contenu. refresh traite le 401 comme une erreur ordinaire. Aucun lien Se reconnecter n’accompagne le message.

**Attendu :** Afficher un avertissement à proximité du contenu, identifier les données comme anciennes et proposer une reconnexion conservant groupe/API.

**Impact :** Anciennes finances potentiellement prises pour l’état courant et difficulté à rétablir la consultation.

**Preuve :** [expiration simulée](web-04-expired.png) ; [web/app.mjs:53](sources/web/app.mjs.html#L53) — ligne 53, `async function refresh()`. Les sources figées HTML permettent d’ouvrir la ligne citée ; les copies `.txt` conservent également le fichier complet.

**Recommandation applicable :** Distinguer les erreurs d’authentification des erreurs réseau ; conserver le contexte et afficher un CTA de reconnexion accessible et visible sans parcourir toute la page.

**Critère d’acceptation :** 401 → avertissement immédiatement visible, données marquées non actualisées, reconnexion accessible ; succès → suppression de l’avertissement et rafraîchissement. 503 conserve un message distinct.

**Exposition / effort estimé :** expiration / révocation / faible à moyen.

### UX17 — Le tournoi du portail omet le nom du troisième camp

**Écran/parcours :** Portail → Séances publiées → tournoi  
**Catégorie :** bug fonctionnel · **Sévérité : modérée** — L’utilisateur voit trois valeurs de victoires mais seulement deux identités de camps.  
**Statut :** confirmé dans le navigateur avec données fictives · **Confiance :** élevé.

**Conditions et reproduction :** Afficher le tournoi synthétique nommé Les Bleus / Les Oranges / Les Verts, victoires 2/1/0.

**Observé :** La carte affiche « Les Bleus · Les Oranges » puis « Victoires A/B/C : 2 / 1 / 0 ». « Les Verts » est absent, car label concatène seulement names.A et names.B.

**Attendu :** Associer explicitement chaque camp A/B/C à son nom et à son nombre de victoires.

**Impact :** Résultat du troisième camp incompréhensible aux membres qui ne connaissent pas la lettre C.

**Preuve :** [tournoi synthétique](web-01-tournament.png) ; [web/app.mjs:35](sources/web/app.mjs.html#L35) — ligne 35, `const label=(names.A||'Équipe A')`. Les sources figées HTML permettent d’ouvrir la ligne citée ; les copies `.txt` conservent également le fichier complet.

**Recommandation applicable :** Rendre une ligne par camp pour les tournois, en utilisant les noms de séance et des replis A/B/C ; garder le classique à deux camps.

**Critère d’acceptation :** Les trois noms personnalisés et trois victoires sont affichés et lisibles à 320 px et au lecteur d’écran.

**Exposition / effort estimé :** chaque tournoi consulté sur le web / faible.

### UX18 — Le pied d’accueil présente un état de sauvegarde cloud qui n’est pas mesuré

**Écran/parcours :** Accueil → Sauvegarder → Réglages  
**Catégorie :** problème UX · **Sévérité : modérée** — La protection des données est une promesse centrale ; le texte laisse croire à un statut cloud alors que le flux est un export manuel.  
**Statut :** confirmé à l’écran et dans le code · **Confiance :** élevé.

**Conditions et reproduction :** Faire défiler l’accueil puis toucher Sauvegarder ; comparer avec l’export décrit dans Réglages.

**Observé :** « Aucune sauvegarde cloud » est une constante. Sauvegarder ouvre simplement Réglages. Le service produit un fichier temporaire et une feuille de partage ; il ne mesure ni copie cloud ni date du dernier export durable.

**Attendu :** Décrire exactement l’export manuel et son statut connu ; distinguer fichier de sauvegarde et synchronisation du groupe.

**Impact :** L’utilisateur peut croire qu’une protection distante est disponible ou suivie ; l’export nécessite plusieurs actions qu’un simple lien ne rend pas explicites.

**Preuve :** [pied d’accueil](27-home-lower.png) ; [mobile/lib/features/home/presentation/home_screen.dart:980](sources/mobile/lib/features/home/presentation/home_screen.dart.html#L980) — ligne 980, `'Aucune sauvegarde cloud'` ; [mobile/lib/features/settings/data/backup_service.dart:24](sources/mobile/lib/features/settings/data/backup_service.dart.html#L24) — ligne 24, `Future<BackupPayload> exportAndShareBackup()`. Les sources figées HTML permettent d’ouvrir la ligne citée ; les copies `.txt` conservent également le fichier complet.

**Recommandation applicable :** Remplacer le faux statut par « Sauvegarde manuelle » avec accès direct à l’export ; expliquer que le fichier doit être conservé hors du téléphone. N’afficher une date cloud que si elle est réellement connue.

**Critère d’acceptation :** Le libellé correspond à l’action déclenchée et ne prétend pas vérifier une copie distante ; après annulation du partage, aucun message ne prétend qu’une copie durable a été déposée.

**Exposition / effort estimé :** chaque sauvegarde / faible à moyen.

### UX19 — La ligne Mentions légales est interactive mais sans effet

**Écran/parcours :** Réglages → À propos  
**Catégorie :** bug fonctionnel · **Sévérité : mineure** — Lien mort localisé, sans blocage des fonctions métier.  
**Statut :** confirmé par le code ; ligne vue sur appareil, appui non retenu comme preuve · **Confiance :** élevé.

**Conditions et reproduction :** Ouvrir Réglages, descendre à À propos, activer Mentions légales.

**Observé :** Le ListTile déclare onTap: () {} : aucune navigation ni contenu.

**Attendu :** Afficher les informations attendues, ou retirer l’affordance jusqu’à disponibilité du contenu.

**Impact :** Action sans retour et crédibilité réduite ; ce constat n’est pas une analyse d’obligation juridique.

**Preuve :** [Réglages bas — nom technique de capture trompeur](28-finances.png) ; [mobile/lib/features/settings/presentation/settings_screen.dart:256](sources/mobile/lib/features/settings/presentation/settings_screen.dart.html#L256) — ligne 256, `onTap: () {}`. Les sources figées HTML permettent d’ouvrir la ligne citée ; les copies `.txt` conservent également le fichier complet.

**Recommandation applicable :** Renseigner la destination et un contenu identifié ; tester le retour à Réglages.

**Critère d’acceptation :** Activation ouvre une destination lisible puis retour fonctionnel ; aucun contrôle actif sans comportement.

**Exposition / effort estimé :** occasionnelle / faible.

## Cohérence globale du design

**Fondation à conserver.** Poppins, cartes arrondies, surfaces hiérarchisées, palette verte et cinq destinations identifiables donnent une identité commune. Les détails de joueur et les synthèses montrent une hiérarchie stable. Les composants PrimaryButton/AppCard, les infobulles de plusieurs compteurs, les états vides spécialisés de Séances et les règles MVP accessibles depuis une aide constituent de bonnes bases. La sélection des camps ne repose pas seulement sur la couleur : lettres et noms complètent les repères.

**Les paires de couleurs sont moins robustes que les tokens.** Le thème clair utilise une couleur foncée sur le vert d’en-tête pour les sous-titres ; les textes d’action alternent entre onPrimaryDark fixe et background950 dépendant du thème. Cela explique des contrastes différents pour des actions pourtant semblables. Définir des rôles sémantiques « texte sur en-tête », « texte de lien sur surface », « texte sur action » évitera de corriger écran par écran. Les valeurs WCAG sont calculées sur les hex opaques du code, pas sur les pixels anti-crénelés des captures.

**Cohérence des identités et des statuts.** Les couleurs d’avatar varient selon le contexte (nom, identifiant ou couleur de profil). Ce point est un affaiblissement du repérage, pas une violation fonctionnelle isolée ; sa priorité dépend d’un test utilisateur. En revanche, l’identité d’un camp doit rester attachée à sa séance (UX13). « Clôturée » dans la liste et « Terminée » dans le détail désignent le même état ; choisir un vocabulaire principal et distinguer clairement Brouillon, En cours, Enregistré localement, À synchroniser, Publié et En conflit. La page partagée n’expose actuellement ni compteur des opérations en attente ni date du dernier succès ; le minuteur ignore ses erreurs en arrière-plan. Ce manque est un risque UX à vérifier sur deux appareils, pas une preuve de perte de synchronisation.

**Composition et densité.** Sur le téléphone observé, cartes et listes restent lisibles dans les états consultés. Les barres d’actions persistantes de l’assistant rendent l’étape suivante disponible. Le sélecteur Match/Tournoi de l’étape 1 affiche cependant ses libellés sur deux lignes contre ses bordures (capture 20) : vérifier les métriques/hauteurs avant d’en faire une correction globale. À ce stade, aucun dépassement avec texte 200 % n’a été testé. Les Rows de métadonnées du sélecteur de groupe, les titres de modales joueur et les KPI à deux colonnes méritent les cas noms longs/texte agrandi ; ce sont des risques structurels, pas des débordements observés.

**Écart web/mobile.** Le portail est une consultation plus sobre, essentiellement à tableaux ; ce choix n’est pas intrinsèquement mauvais. La police déclarée Poppins n’est pas chargée par une ressource web : la capture utilise une police de repli, contrairement au mobile embarqué. Ce point de cohérence visuelle reste secondaire à l’harmonisation des données et des états. Le portail n’affiche pas de message spécifique sous « Points financiers publiés » si la liste est vide : ajouter « Aucun point publié » expliquerait le blanc observé, sans urgence équivalente aux problèmes financiers.

## Accessibilité : résultats et vérifications restantes

Les références sont les [critères officiels WCAG 2.2 du W3C](https://www.w3.org/WAI/WCAG22/quickref/). Elles servent de grille d’analyse et ne constituent pas une certification du client Flutter natif. UX08 documente les contrastes ; UX15 documente les états sélectionnés ; UX10 et UX11 ciblent focus/clavier et erreurs de formulaire.

- Le portail possède `lang=fr`, des labels associés aux champs, des boutons natifs et un statut `aria-live`. La validation vide native a été observée ; Tab passe de Classement à Finances. L’ordre complet et un lecteur d’écran n’ont pas été testés.
- Plusieurs champs de création joueur ont un texte visuel « Nom »/« Surnom » séparé du TextField avec seulement un hint. Vérifier leur nom accessible persistant après saisie ; l’édition utilise des labelText. Le bouton + « créer et enchaîner » est une icône sans libellé/tooltip explicite. TalkBack devra confirmer l’annonce et l’ordre des champs.
- Le CDC demande des cibles ≥44 px. Les filtres personnalisés ont une hauteur liée au texte et à 16 px de padding ; ils peuvent rester sous ce seuil. Leur mesure à l’écran logique et leurs espacements doivent précéder tout verdict WCAG 2.5.8 (seuil minimum et exceptions différents du critère renforcé 2.5.5).
- Aucun test TalkBack/VoiceOver, switch control, clavier matériel Android, texte système 200 %, zoom web 200/400 % ou réduction d’animations n’a été réalisé. Les animations répétées de l’onboarding et les FittedBox de compteurs/score sont des zones ciblées pour 1.4.4, 1.4.10 et les préférences de mouvement. Leur simple présence ne prouve pas un échec.

## Plan priorisé : impact × exposition × effort

| Lot | Constats | Impact et raison | Effort relatif | Validation de sortie |
|---|---|---|---|---|
| P0 — protéger les données avant diffusion | UX01, UX02, UX03, UX07 | Remplacement involontaire, saisies perdues, échéances confondues, restauration qui change le classement | Moyen, avec migrations/compatibilité à évaluer pour UX03 | Copies isolées : annulation intacte ; brouillons repris ; deux séances même jour séparées ; tournoi restauré identique |
| P1 — rendre les décisions et droits compréhensibles | UX04, UX05, UX06 | Arbitrage et approbation vérifiables ; aucun parcours de saisie sans droit | Moyen à important | Jeux de conflits représentatifs et matrice réelle ADMIN/PDT/SG/TR/MEMBER sur deux appareils |
| P1 — lisibilité immédiate | UX08 | Très fréquent en thème clair ; correction mutualisable | Faible | Contrastes de toutes les paires réelles, puis vérification clair/sombre |
| P2 — fiabiliser la saisie | UX10, UX11, UX12 | Clavier, erreurs, double appui : fréquents lors d’encaissements et premiers usages | Faible à moyen | Champs invalides conservés ; dernier membre visible ; une seule écriture par soumission |
| P2 — confiance entre vues et plateformes | UX09, UX13, UX16, UX17, UX18 | Classement/identités cohérents, états de consultation et sauvegarde honnêtes | Faible à moyen | Même scénario mobile/web, reconnexion 401, noms/camps personnalisés et export annulé |
| P2 — accessibilité des commandes | UX15 | Accès indépendant de la perception visuelle | Moyen | Parcours réel clavier + TalkBack/VoiceOver après vérification des noms/rôles/états |
| P3 — personnalisation et finitions | UX14, UX19 + police web, état vide financier | Cohérence de photos et suppression des liens morts | Faible à moyen | Photos persistantes/repli, liens fonctionnels, contenu vide explicite |

Estimation relative : faible ≈ correction localisée ; moyen ≈ plusieurs couches/parcours et tests ; important ≈ conception de comparaison + règles d’approbation. Aucun délai en jours n’est garanti sans chiffrage avec l’équipe. Commencer par des scénarios d’acceptation et des données isolées ; ne pas lancer une refonte visuelle qui masquerait les risques de données.

## Points forts à préserver

1. Navigation principale stable, icône et libellé pour chaque onglet ; possibilité de revenir des détails.
2. Composition en deux étapes, retour à l’étape précédente et confirmation d’abandon après sélection : le scénario consulté protège bien ce contexte temporaire.
3. Responsabilités métier distinctes, contrôles d’écriture dans les contrôleurs et validations de clôture relues avant écriture ; l’audit critique leur représentation UX, pas leur absence généralisée.
4. Séparation cotisation/pénalité, récapitulatif avant validation financière, conservation de l’historique et motif pour correction : ce sont les bons concepts à rendre visibles et récupérables.
5. États vides et retry déjà présents dans plusieurs vues de classement/statistiques ; aide sur le MVP et personnalisation de camps avec noms/lettres.
6. Portail sans saisie métier, rendu de texte via textContent, formulaires HTML étiquetés et tableaux défilants à petite largeur ; ne pas supprimer ces bases au profit de contrôles purement graphiques.

## Préférences et hypothèses : à ne pas confondre avec les défauts

- Réduire la hauteur des cartes ou rapprocher Finances du haut de l’accueil pourrait accélérer la consultation du trésorier. Ce n’est pas un défaut démontré : mesurer d’abord les tâches et leur fréquence selon rôle.
- Un vocabulaire entièrement français à la place de « MVP », « ratio » et « J/V/N/D » peut aider les nouveaux utilisateurs ; tester la compréhension avec une personne du groupe avant de changer des repères familiers.
- Le grand nombre de rôles, l’URL API et l’identifiant du groupe ajoutent une charge d’onboarding. Un lien de connexion préconfiguré pourrait la réduire, mais aucune étude utilisateur n’a mesuré cet obstacle. Le champ API du portail est actuellement visible et requis ; le mobile le place sous Serveur.
- La comparaison exhaustive aux captures historiques et un redesign esthétique ne sont pas nécessaires pour corriger les risques objectifs ci-dessus. Aucune remarque n’est retenue au seul motif que la palette, le rayon ou la police ne correspondent pas à un goût personnel.

## Limites et recette restante

**Surface du code inventoriée ; couverture d’exécution partielle.** Les écrans conditionnés par un premier lancement ou un compte partagé n’ont pas tous été ouverts. Finances a été ouverte sur un groupe vide, et Groupe partagé sur ses formulaires de connexion/partage ; cela ne valide ni un encaissement ni les vues de gestion authentifiée. Les autres variantes ont été étudiées dans leur code courant et les tests widgets existants. Les routes réelles ne sont pas rendues accessibles artificiellement en modifiant l’application.

À reprendre dans une recette isolée, par ordre :

1. Base de démonstration indépendante + deux connexions de test et deux appareils : création groupe/compte, attribution PDT/TR/SG, publication, hors ligne, conflit, choix de version, transfert, révocation et expiration. Aucune information de compte réel n’a été demandée.
2. Encaissements complets, paiement partiel/avance, dette de pénalité antérieure, don/dépense, zéro et montants extrêmes, 50 membres, annulation, correction avec motif ; retour, fermeture processus et reprise. Ne jamais assimiler un placeholder au montant reçu.
3. Classique et tournoi : minima/équilibre, noms et couleurs identiques, noms longs, retards, score/buteurs/passes/cartons, clôture 0-0 et incohérente, réouverture et suppression sur copie. Différence avertissement/blocage à arbitrer avec le produit.
4. Sauvegarde/restauration de plusieurs groupes, tournois, photos, ancienne version et version future. Le parser lit une version mais ne refuse pas explicitement les versions futures ; valider ce risque avant livraison. La fusion est annoncée « recommandée » dans l’UI alors que le service refuse les backups financiers/partagés : tester et ajuster les choix proposés selon le fichier.
5. iOS/VoiceOver/galerie : Info.plist ne déclare pas NSPhotoLibraryUsageDescription dans le fichier examiné. Le crash ou refus dépend de la plateforme et du mode de sélection ; **à vérifier sur iPhone**, aucun crash iOS affirmé. Tester les descriptions de permission, le refus et la reprise ; portrait/paysage et zones sûres.
6. Texte 200 %, 320/360 dp Android, tablette, paysage si supporté, zoom navigateur, longues chaînes, clavier matériel/assistances, réduction animations. Respecter les seuils et exceptions propres à chaque critère WCAG.
7. Performance : démarrage froid/chaud et reprises, 50 joueurs/500 séances, chronométrage de la saisie complète, réseau lent/timeout/503 et stabilité du layout. Aucun verdict chiffré de performance ne peut être tiré de cet audit.

Les captures ne sont pas des golden tests ; la campagne Flutter ciblée n’est pas entièrement verte. Les autres tests, migrations et un vrai backend n’ont pas été validés globalement. Le rapport peut guider les corrections, mais une recette de version figée est nécessaire pour conclure sur la qualité d’une livraison.

## Livrables et reproductibilité

- `rapport.md` : rapport complet ; `couverture.csv` : matrice exploitable ; `constats.json` : fiches structurées.
- `preuves.html` : planches annotées par surimpression CSS sur les captures originales, sans retouche des pixels ni du contenu applicatif.
- `source-manifest.json` et `sources/` : empreintes et copies des fichiers cités. Les références de lignes pointent vers ces copies ; le hash fixe la preuve malgré les évolutions du dépôt.
- `portal_fixture.py` : API locale fictive ; `check-ranking.mjs` : reproduction du départage. Ce sont des outils de l’audit, pas du produit. Pour rejouer : servir web sur 8087, lancer la fixture sur 8088 puis utiliser n’importe quels identifiants fictifs ; le serveur ne les vérifie pas et n’a aucun lien vers un service externe. Le fichier `fixture-expired.flag`, s’il existe, force un 401 sur les lectures.

