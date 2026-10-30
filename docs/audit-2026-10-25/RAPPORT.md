# Audit complet de l’état actuel de Statoo

Date : 25 octobre 2026 — référence `staging`, commit `1daa008`.

## 1. Verdict

**Statoo possède un socle fonctionnel étendu et une régression automatisée solide. La version ne peut néanmoins pas être considérée comme prête à une diffusion générale : l’audit reproduit des problèmes de migration, de conservation de modifications et de validation serveur que la suite existante ne couvre pas.**

Le parcours local nominal a été parcouru dans le navigateur : introduction, création de groupe, ajout de six joueurs, composition, démarrage explicite, but avec passe, clôture et célébration, classement et statistiques. Le point financier a été ouvert et sa protection contre l’abandon vérifiée. Les accès gestionnaires ont été vérifiés par un test navigateur avec API réelle locale.

Cet audit couvre le client Flutter Android/iOS/web, l’API FastAPI, le portail historique, les données, la synchronisation, l’interface, l’accessibilité, les performances, les dépendances et la livraison. **Il ne constitue ni une certification WCAG, ni un pentest de production, ni une validation sur appareils physiques.** Aucun pourcentage global d’achèvement ou de conformité n’est attribué : le CDC initial et le périmètre actuel diffèrent substantiellement.

## 2. Périmètre, méthode et protection des données

- Références : `AGENTS.md`, conventions, design system, contrat de parité, code courant, tests, historique Git et CDC v1.1 en PDF, dont le texte a été extrait et relu.
- Scénarios complémentaires écrits avant les sondes : [scenarios.md](scenarios.md).
- Les sondes API utilisent SQLite en mémoire. Les sondes Flutter utilisent des données fictives, du stockage sécurisé simulé et une base de migration créée sous `/tmp`.
- Le navigateur utilise le build courant, une origine locale dédiée et des comptes fictifs. Aucun compte utilisateur ni service public n’a été modifié.
- Aucun correctif applicatif, changement de dépendance, migration utilisateur, commit, push ou déploiement n’a été effectué.
- Les captures et résultats générés par les tests existants ont été regroupés dans ce dossier. Les preuves suivies par Git et écrasées par ces tests ont été restaurées à leur état initial.
- État initial : branche alignée avec `origin/staging`, seuls `android/` et `ios/` racine non suivis. Ce sont des vestiges distincts du projet Flutter sous `mobile/` ; ils n’ont pas été modifiés.

Qualifications utilisées : **reproduit** = constat exécuté ; **lecture** = chemin identifié dans le code ; **limite** = contrôle non exécuté. P1 : intégrité ou parcours essentiel ; P2 : défaut important/risque opérationnel ; P3 : cohérence et maintenabilité. Aucun P0 n’a été démontré ; cela ne prouve pas l’absence de vulnérabilité critique.

## 3. Résultats exécutés aujourd’hui

| Contrôle | Résultat courant | Portée et preuve |
|---|---|---|
| Flutter, suite existante complète | **825 réussis**, 0 échec, 7 min 08 s | `flutter test --reporter compact`, résultat observé dans la session ; résumé conservé dans `execution-summary.md`. |
| Backend, suite complète | **89 réussis**, 1 avertissement, 494,80 s | [backend-tests.txt](backend-tests.txt), TestClient et bases isolées. |
| Web unités/packaging | **16 fichiers de tests réussis** | [web-unit-and-package.txt](web-unit-and-package.txt). Le reporter compte ici les fichiers ; ne pas présenter ce total comme 16 assertions. |
| Portail historique, navigateur | **110/110 réussis** au passage final | [legacy-browser-final.txt](legacy-browser-final.txt). |
| Accès gestionnaire, Flutter web + API locale | **1 parcours composé réussi** | [manager-browser-final.txt](manager-browser-final.txt) : création, copie, connexion dans un second contexte, reprise après reload, annulation et remplacement confirmé. |
| Focus iOS simulé et enveloppe Flutter | **3/3 réussis**, puis **18 configurations réussies** | [responsive-browser.txt](responsive-browser.txt) et [responsive-browser-full.txt](responsive-browser-full.txt) : 320/390/393 px × texte 100/130/200 % × clair/sombre. La matrice porte sur bienvenue/création/enveloppe, pas tous les parcours. |
| Analyse Flutter complète | **0 erreur, 2 avertissements, 132 informations** | [flutter-analysis.txt](flutter-analysis.txt), 146 s. Avertissements dans les tests : import inutilisé et type Map brut. |
| Build Flutter web release | **Réussi**, 358,2 s | [flutter-build.txt](flutter-build.txt), cible `main_web.dart`, API locale injectée au build. |
| Package universel | **Réussi**, 52 ressources Flutter | [universal-package.txt](universal-package.txt), hash local `c60a1d72295a4b15`. Ce hash n’identifie pas une version publique. |
| Sondes API complémentaires | 17 observations | [api-probes.json](api-probes.json), plusieurs violations reproduites détaillées ci-dessous. |
| Sondes Flutter complémentaires | **5 scénarios en échec comportemental** | [flutter-probes-historical.txt](flutter-probes-historical.txt) et [sync-probes.txt](sync-probes.txt). Ils démontrent des défauts, sans correction dans cet audit. |
| Cohérence des dépendances Python | `pip check` réussi | Ne constitue pas un scan de CVE. |
| Vulnérabilités npm connues | **0 signalée**, 64 dépendances recensées par npm | [npm-audit.json](npm-audit.json), inclut les dépendances de développement ; aucune garantie globale de sécurité. |
| Charge SQLite synthétique | 50 joueurs, 500 séances, 5 000 participations | [sql-benchmark.json](sql-benchmark.json), détails section performances. |

Incidents exclus du verdict produit : premier lancement pytest depuis la mauvaise racine (imports `app`), blocage du TestClient dans le bac à sable, cache Flutter non inscriptible, CORS de l’origine locale d’audit et interruption d’un serveur de test. Après adaptation de l’environnement, les passages finaux sont ceux du tableau. La première fixture de migration, dérivée du schéma actuel, contenait des triggers anachroniques ; elle a été remplacée par les instructions SQL exactes de `1a3af10`, version 6. Seule cette seconde reproduction fonde le constat de migration.

## 4. Constats prioritaires reproduits

### F01 — P1 — Une base historique v6 ne peut pas s’ouvrir avec la migration actuelle

**Reproduit.** Une base temporaire construite à partir des tables et vues exactes du commit `1a3af10`, avec un groupe, un joueur, une séance et une participation, échoue à l’ouverture via `AppDatabase.instance.database` courant. SQLite retourne `error in view v_player_match_results: no such table: main.sessions` pendant `ALTER TABLE sessions_new RENAME TO sessions`.

La reconstruction supprime `sessions` avant de retirer les vues qui la référencent ; `_dropViews` arrive après la migration. Le `PRAGMA foreign_keys = OFF` se trouve aussi à l’intérieur du callback transactionnel, ce qui mérite une vérification spécifique de conservation des enfants lorsque le blocage des vues sera traité. **L’audit prouve un blocage d’ouverture, pas une perte définitive de la base utilisateur.** La portée Android/iOS doit être rejouée sur leurs moteurs SQLite réels.

Source : `mobile/lib/core/data/app_database.dart`, `onUpgrade`, lignes 106–158. Preuve : [probe_flutter_test.dart](probe_flutter_test.dart), [historical-v6-schema.json](historical-v6-schema.json), [flutter-probes-historical.txt](flutter-probes-historical.txt).

### F02 — P1 — La synchronisation efface une modification locale de membre non publiée

**Reproduit.** Après import d’Alice, un changement local vers « Alice corrigée », avec archivage, est remplacé par le snapshot serveur contenant l’ancienne identité. Le test retrouve `Alice` au lieu du nouveau nom.

Les mutations de `PlayersNotifier` écrivent dans SQLite. La publication des membres reste une action distincte « Mettre à jour les membres » dans Groupe partagé. Entre-temps, `importSnapshot` met les lignes à jour sans brouillon ni arbitrage de répertoire. Le timer de synchronisation peut donc écraser un renommage/archivage avant cette publication. Un joueur nouvellement créé, absent du serveur, expose aussi ses futures séances à un refus « participant inconnu » tant que le répertoire n’est pas publié ; cette conséquence est déduite du contrat serveur, pas d’un parcours navigateur reproduit ici.

Sources : `mobile/lib/features/players/application/players_provider.dart`, `mobile/lib/features/shared/data/shared_service.dart:555`, `shared_group_screen.dart:1221`. Preuve : [probe_sync_test.dart](probe_sync_test.dart), [sync-probes.txt](sync-probes.txt).

### F03 — P1 — Le contrat sportif serveur accepte des documents invalides

**Reproduit avec un compte autorisé ; aucun contournement d’authentification démontré.** `/sync` répond 200 pour : date non ISO, type de séance inconnu, tournoi avec victoires négatives et vainqueur incohérent, équipe C dans un classique avec dérogation d’effectif, buts non attribués négatifs compensant un but joueur, identifiants de participation absents ou dupliqués.

Le snapshot contient ensuite ces documents. Les clients utilisent `DateTime.parse`, des conversions strictes et des insertions SQLite : ces entrées constituent un risque de blocage d’import et de statistiques incorrectes pour le groupe. La propagation exacte de chaque variante dans tous les clients n’a pas été exécutée ; l’acceptation et la persistance serveur le sont.

Deux variantes mal formées produisent **500** : date absente et `player_id` de type liste. Le contrôle négatif « score chaîne » renvoie bien **422**, ce qui montre que la sonde atteint la validation réelle.

Source : `backend/app/main.py:670`, `validate_sport`, et construction des obligations dans `sync`. Preuve : [probe_api.py](probe_api.py), [api-probes.json](api-probes.json).

### F04 — P2 — La déconnexion hors ligne laisse l’identité et le jeton sur l’appareil

**Reproduit.** Une erreur réseau sur `/auth/logout` interrompt `disconnect()` avant l’effacement des secrets et la remise à zéro de l’identité. La sonde retrouve le jeton fictif après la tentative.

Cela ne contourne pas une révocation serveur, mais empêche l’utilisateur de terminer localement sa déconnexion quand le serveur est inaccessible ou la session expirée. Source : `shared_service.dart:151`. Preuve : [flutter-probes-historical.txt](flutter-probes-historical.txt).

### F05 — P2 — Une opération refusée peut bloquer toute la file suivante

**Reproduit.** La première opération simulée reçoit 403 ; la seconde, indépendante et acceptée par la fixture, n’est jamais envoyée. Hors cas particulier `active_session_conflict`, la boucle relance l’exception. Le timer l’absorbe avec `catchError`, et le calcul de l’avertissement est placé après la boucle.

Les opérations restent conservées, ce qui protège les données, mais la reprise exige de comprendre un blocage que le traitement automatique ne transforme pas en état explicite par opération. Source : `shared_service.dart:142`, `synchronize`, `_refreshSyncWarning`. Preuve : [sync-probes.txt](sync-probes.txt). Le test s’arrête sur l’absence du second envoi ; l’absence d’avertissement découle en plus de la lecture du chemin d’exception.

### F06 — P2 — Collision Admin/collectif après normalisation des identifiants

**Reproduit.** Créer `admin` et ` admin ` comme identifiants respectifs est accepté en 201. Ils sont ensuite tous deux stockés sans espaces. La connexion avec le mot de passe collectif échoue en 401, la recherche retrouvant le premier compte.

Le contrôle de distinction fait `casefold()` avant `strip()` à l’inscription, contrairement au stockage et à la connexion. Ce cas ne démontre pas de prise de contrôle ; il démontre un accès collectif créé mais inutilisable. Source : `backend/app/main.py:265`, `register`, `login`. Preuve : [api-probes.json](api-probes.json).

### F07 — P2 — Une sauvegarde de version future est acceptée

**Reproduit.** `BackupPayload.fromJson` accepte `version: 999` au lieu de refuser. `restoreBackup` ne possède pas non plus de garde supérieure de version avant les mutations. Le risque est une interprétation silencieuse d’un format inconnu, notamment en restauration complète. La sonde démontre l’acceptation du parseur, sans effacer de base utilisateur.

Source : `mobile/lib/features/settings/domain/backup_payload.dart:22`, `backup_service.dart:130`. Preuve : [flutter-probes-historical.txt](flutter-probes-historical.txt). Exigence explicite du CDC §10.

### F08 — P2 — Plusieurs commandes n’ont pas de nom accessible ou de contexte suffisant

**Observé dans l’arbre d’accessibilité du build courant.** Bouton Retour de création de groupe sans nom ; boutons de retrait dans l’ajout initial sans nom ; bouton flottant de la liste des séances sans nom. En composition, les commandes répétées « Présent », « A », « B » et « Retirer » ne nomment pas le joueur concerné. Le champ de recherche est exposé avec un long regroupement de textes de composition.

Ces défauts rendent la navigation par liste de commandes/lecteur d’écran ambiguë. Les boutons d’ajout de but, eux, annoncent correctement le joueur. Sources : `create_team_screen.dart:163`, `add_team_players_screen.dart:539`, `sessions_screen.dart`, `new_session_screen.dart`. Le résultat d’un lecteur d’écran réel reste à valider ; l’absence de nom dans l’arbre courant est constatée.

### F09 — P2 — Les erreurs de validation génériques renvoient le secret soumis

**Reproduit.** Un mot de passe trop court transmis à `/auth/login` apparaît dans le champ `input` de la réponse 422. Il s’agit du secret fourni par l’appelant, pas du mot de passe d’un autre compte. Le risque concerne les journaux réseau, proxies, outils de diagnostic et remontées d’erreurs. Les nouvelles routes de vérification de mot de passe ont, elles, un message générique de longueur.

Source : modèles Pydantic `Credentials` et gestionnaire d’erreurs par défaut FastAPI. Preuve : indicateur booléen dans [api-probes.json](api-probes.json) ; aucun secret utilisateur n’a été enregistré dans les preuves.

### F10 — P3 — L’API sert aussi les sources de tests du portail

**Reproduit.** `/portal/tests/client.test.mjs` répond 200 sans authentification : le montage statique vise `web/` entier. La traversée testée vers `backend/app/main.py` répond 404. Aucun secret révélé n’a été démontré. C’est une exposition inutile des fixtures et de la structure interne, distincte d’une fuite d’accès aux fichiers serveur.

Source : `backend/app/main.py:176`, montage `StaticFiles`. Preuve : [api-probes.json](api-probes.json).

### F11 — P2 — Le rechargement direct des statistiques affiche un faux état vide

**Observé dans le navigateur sur le groupe fictif.** Avant rechargement, `/stats` affiche 1 séance, 6 joueurs, 1 but, 1 passe. Après rechargement direct de cette route, les totaux sont à zéro. Passer par l’accueil rétablit la séance et les membres, puis Stats retrouve les valeurs correctes. **Ce n’est pas une perte des données SQLite.**

`main()` retrouve le groupe au démarrage mais n’initialise pas `activeTeamIdProvider`. Celui-ci commence à null ; le chargement de `TeamInfoNotifier`, déclenché notamment par l’accueil, le remplit ensuite. Stats dépend de cet identifiant et retourne un modèle vide tant qu’il manque. Un lien direct/rechargement ne doit pas dépendre d’un passage par l’accueil pour retrouver le contexte.

Sources : `mobile/lib/main.dart`, `mobile/lib/features/team/application/team_provider.dart:35`, `mobile/lib/features/stats/application/stats_providers.dart`. Preuve manuelle : [reload-observations.md](reload-observations.md), scénario AUD-18. Les autres routes et plateformes ne sont pas assimilées à ce cas sans reproduction.

## 5. Fonctionnalités et parcours

| Domaine | Ce qui existe et a été vérifié | Limites/écarts actuels |
|---|---|---|
| Premier lancement | Splash, présentation, choix créer/rejoindre ; ordre nominal observé. | L’indicateur « Étape 2 sur 2 » précède encore l’accès Admin et les responsabilités : progression globale peu explicite. |
| Mode local | Groupe et joueurs créés sans compte ; séance complète effectuée. | Le choix sans compte se trouve sous les formulaires d’accès partagé ; il n’est pas annoncé au choix initial. |
| Groupes multiples | Sélecteur, données scopées, tests d’isolation. | La connexion partagée active est unique ; la gestion simultanée de plusieurs connexions/serveurs n’est pas un parcours offert. |
| Joueurs | Recherche, surnoms, création, fiche, édition, archivage, garde de suppression d’un joueur ayant joué. | Publication du répertoire séparée des mutations ; F02. Photos natives et portabilité : réserves ci-dessous. |
| Préparation sportive | Date/options, présents, tirage ou affectation manuelle, noms/couleurs, démarrage explicite. | Validation API plus permissive que Flutter ; F03. |
| Saisie live | But puis passe facultative, cartons, annulation et journal local ; but+passe observés. | Journal annoncé comme historique de cet appareil ; il n’est pas transmis comme journal d’événements autonome dans le contrat sport. Pas de parité de correction d’historique interappareils démontrée. |
| Cycle de séance | Brouillon/active, clôture, réouverture, annulation, unicité d’active et conflits testés. | La confirmation de clôture observée nomme encore « Équipe A » malgré le nom personnalisé affiché avant/après. |
| Tournoi | Trois camps, compteurs de victoires, égalités, barème configurable, tests métier. | Pas de rencontres internes, calendrier ou rotation de camp au repos ; c’est le modèle voulu actuellement, pas un moteur de championnat. Validation serveur des victoires insuffisante. |
| Classements | Points, ratio avec éligibilité, buteurs, passeurs, cartons, MVP mensuel, filtres. | La vue observée attribue correctement 3 points aux gagnants, 0 aux perdants. Toutes les combinaisons de filtres ne sont pas rejouées manuellement. |
| Statistiques | Totaux groupe, individuelles, historique ; groupe observé à 1 séance, 1 but, 1 passe, 6 actifs. | F11 : faux état vide au rechargement direct. La fraîcheur de toutes les fiches déjà ouvertes après synchronisation reste à reproduire : les providers de détail individuels ne sont pas tous invalidés explicitement. |
| Finances | Cotisations, sanctions distinctes, dons/dépenses, point sans sport, annulation, soldes initiaux et approbation, corrections motivées. | Cas métier couverts par suite ; aucun paiement réel. Les montants préremplis imposent de retirer les impayés, sinon risque de fausse déclaration par inattention. |
| Partage et rôles | Admin, présidence, secrétariat, trésorerie, censeur, collectif en lecture seule ; contrôles serveur. | Attribution PDT et TR requise avant première synchronisation métier ; risque d’étonnement si l’étape initiale a été passée. |
| Comptes/accès | Mot de passe gestionnaire généré, vérifié/copier, remplacement confirmé, révocation ciblée ; parcours Chrome réussi. | Pas de procédure de récupération du mot de passe Admin ni de changement autonome repérée dans les routes examinées. |
| Conflits | Versions candidates, révisions, génération, motifs, arbitrage et transfert. | F05 ; la recette humaine sur deux téléphones simultanés et PostgreSQL n’est pas réalisée ici. |
| Sauvegarde | JSON, aperçu/confirmation, fusion ou remplacement ; fusion financière/partagée refusée explicitement. | Pas de backup cloud automatique, F07, atomicité étendue et photos à vérifier. |
| PWA | Installation/aide iOS, mise à jour confirmée, cache versionné, ressources locales. | Pas de recette système installée, quota/éviction navigateur, multi-onglets, WebKit/Firefox dans cet audit. |

**Correction du bilan précédent :** la différence historique de droits financiers Admin n’est plus visible dans le contrat courant de `SharedService.permits` : finance = TR/TGA, paramètres financiers = Admin/TR/TGA, comme l’API. L’ancien compte rendu de fusion ne doit donc pas être traité comme preuve d’un défaut actuel sur ce point.

## 6. UI/UX et accessibilité transversales

### Ce qui fonctionne dans les écrans vus

Poppins, palettes claire/sombre définies, composants partagés, hiérarchie nette par cartes, boutons principaux larges et messages métier français. Le menu PWA dispose d’une bande réservée et n’empiète pas sur les en-têtes contrôlés. Les noms de camps et les statistiques sont lisibles sur la largeur observée. Les dialogues de but/passeur empêchent une passe du buteur à lui-même dans le choix proposé. Les écrans distinguent « En cours » et « Terminée » ; les commandes de saisie disparaissent après clôture. Le point financier demande confirmation avant abandon, y compris pour le préremplissage non validé.

Les tests de contraste des composants principaux et les variantes de cadrage Flutter font partie des 825 tests exécutés. Les 18 configurations navigateur actuelles couvrent l’enveloppe, la bienvenue, la création et l’accès à sa validation, avec saisie conservée et aucune erreur JavaScript observée. Elles couvrent moins d’écrans que la matrice widget. Les captures historiques ne sont pas présentées comme une recette actuelle de tous les écrans.

### Frictions et risques visibles/identifiés

- **P2, F08 :** noms accessibles manquants et commandes répétées sans joueur ; recherche de composition exposée avec trop de texte.
- **P2, lecture :** plusieurs liens construits avec `GestureDetector` et simple texte méritent une recette clavier dédiée ; la présence d’une interaction tactile ne démontre pas son activation par Entrée/Espace. Pas de verdict automatique de conformité clavier globale.
- **P2, observé :** le dialogue « Quitter sans enregistrer ? » met « Abandonner les modifications » en bouton vert plein et « Continuer la saisie » en action secondaire. Cela donne à l’action qui jette la saisie le poids visuel d’une validation courante.
- **P2, observé :** le point financier annonce 600 F encaissés dès l’ouverture pour six joueurs, avant saisie individuelle. Le texte précise le préremplissage et la nécessité d’effacer les impayés ; il ne s’agit pas d’un paiement déjà enregistré. Ce choix accélère le cas « tous payés » mais augmente le risque de validation erronée.
- **P3, observé :** nom du groupe dupliqué dans le nom accessible de l’accueil ; confirmation de clôture générique A/B ; progression du premier parcours sous-estimée.
- **P3, lecture :** tailles de 9–11 px dans des informations secondaires et abréviations J/V/N/D/B/P du classement ; densité et compréhension à évaluer avec de vrais utilisateurs et grand texte.
- **Limite :** les cibles de tous les contrôles n’ont pas été mesurées. Le test navigateur observé retourne un bouton de bienvenue de 40 px de haut ; cela est inférieur à la cible projet de 44/48, mais ne suffit pas à déclarer un échec WCAG 2.2 AA (minimum différent et exceptions). Ne pas confondre les référentiels.

Référentiel de lecture : [WCAG 2.2 du W3C](https://www.w3.org/TR/WCAG22/), notamment contraste, nom/rôle/valeur, clavier, focus et cibles. Aucun lecteur d’écran physique, test complet d’ordre de lecture, reconnaissance vocale, daltonisme ou commande par contacteur n’a été exécuté. Les confettis respectent la préférence de réduction des animations ; l’introduction animée n’a pas de branche `disableAnimations` repérée, ce qui reste à examiner sur le rendu réel avec cette préférence.

## 7. Sécurité, confidentialité et contrôle d’accès

### Protections confirmées par code et régression

- Mots de passe salés, PBKDF2-SHA256 à 600 000 itérations ; comparaison à temps constant.
- Jetons aléatoires de 32 octets avant encodage ; seule leur empreinte SHA-256 est conservée dans la table serveur. Expiration à 30 jours ; révocation logout et rotations.
- Authentification, rôle, identité collective et appartenance au groupe contrôlés côté serveur. Une étiquette de rôle côté client ne suffit pas à écrire avec un accès collectif.
- Pas de mots de passe/empreintes dans le snapshot nominal testé. Candidats/historique limités à PDT/VP ; liste complète des comptes réservée à l’Admin.
- Isolation locale via `team_id`, requêtes paramétrées, clés étrangères et triggers de participations ; tests associés réussis sur schéma frais.
- Secrets de connexion et nouveaux accès mémorisés dans FlutterSecureStorage, hors SQLite/JSON de backup. Namespace par serveur/groupe/Admin/cible ; copie explicite après vérification ; pas d’affichage du secret gestionnaire dans la fiche.
- Connexion distante HTTPS exigée ; exception HTTP limitée au développement local. URL contenant `#` encodée.
- Pas de secret serveur suivi parmi les fichiers sensibles repérés par l’inventaire Git ; `.env*` et keystores ignorés. Ce contrôle de surface n’est pas une recherche certifiée de secrets dans tout l’historique.

### Risques opérationnels/de conception — lecture, sans attaque de charge

1. **P2 — Protection contre abus partielle.** Limiteur uniquement en mémoire sur le login, par IP, 20 tentatives/minute. Succès réinitialisant le compteur ; pas de partage interworkers ni nettoyage global du dictionnaire repéré. Inscription publique et vérifications PBKDF2 ne disposent pas d’un budget global dans le code. Le verrou Python unique enveloppe les transactions de tous les groupes : un travail lent bloque aussi les autres requêtes de ce processus. Aucun DoS public n’a été tenté.
2. **P2 — Volumétrie non bornée.** État de groupe JSON contenant documents, historique, candidats, opérations et audit ; ces collections croissent sans rétention/pagination. Corps sport/membres partiellement typés, champs supplémentaires et taille globale non bornés applicativement. Limites éventuelles du proxy/hébergeur non inspectées. Référence : [OWASP API4, consommation de ressources](https://api-security.owasp.org/editions/2023/en/0xa4-unrestricted-resource-consumption/).
3. **P2 — Sessions et récupération.** Jeton porteur valable 30 jours ; aucun renouvellement distinct, MFA ni récupération Admin repéré. Ce sont des capacités absentes, pas un exploit démontré. F04 aggrave le cas de déconnexion sans réseau.
4. **P2 — Confidentialité locale.** Les données sportives/financières, snapshots, audit et opérations sont dans SQLite et exportables en JSON non chiffré. Le chiffrement des identifiants ne chiffre pas les dossiers métier. L’accès collectif est une identité commune, donc sans attribution individuelle des consultations. Aucun test de sauvegarde système Android/iCloud, de téléphone compromis ou d’accès au profil navigateur n’a été réalisé.
5. **P2 — Politique de données non matérialisée.** Pas de parcours de suppression de compte distant, de suppression complète de groupe distant, d’information de conservation ou de politique de confidentialité repéré. La suppression locale d’un groupe ne démontre pas une suppression serveur. Il s’agit d’un constat produit/documentaire, pas d’un avis de conformité juridique.
6. **P2 — En-têtes et surface publique.** Pas de politique CSP, frame-ancestors, HSTS ou middleware d’en-têtes de sécurité déclaré dans la configuration versionnée examinée. L’hébergeur peut en ajouter ; les en-têtes publics ne sont pas audités ici. `/docs` et OpenAPI restent disponibles par défaut ; leur présence seule n’est pas une faille.
7. **P3 — Audit non indépendant.** Le journal d’activité est stocké dans le même état JSON que les données et n’est pas un journal externe immuable. Cela réduit la portée de preuve en cas d’accès direct à la base.

Les vulnérabilités de dépendances Dart et Python n’ont pas été interrogées contre une base d’avis dédiée. Les paquets Python ne sont pas verrouillés par versions exactes ; les builds peuvent résoudre un environnement différent. Le scan npm est vert, sans extrapolation aux autres écosystèmes.

## 8. Données, migrations, backup et synchronisation

### Intégrité

Le schéma local est en version SQLite 8 ; contraintes de statut et de camps, unicité joueur/séance, FK et garde intergroupes sont présentes. **Il n’impose pas en SQL toutes les règles de clôture ni des bornes non négatives sur les statistiques.** Leur respect dépend des chemins applicatifs ; F03 montre la faiblesse d’un point d’entrée serveur.

Le marqueur `meta.schema_version` reste écrit à `1` alors que `openDatabase(version: 8)` pilote les migrations. Cela entretient deux indicateurs de version différents. F01 couvre le passage v6→v8 ; les autres anciens schémas, sauvegardes réellement distribuées et données atypiques ne sont pas tous rejoués. Les tests courants se concentrent largement sur des créations fraîches et la migration additive de personnalisation.

### Sauvegarde/restauration

Restauration SQL transactionnelle et confirmation de remplacement de tous les groupes ; contrôle du contexte avant remplacement. La fusion financière/partagée est explicitement refusée. Le traitement actuel des tournois vérifie les victoires/résultat : l’ancien constat « tournoi forcément rétrogradé faute de score A/B » ne s’applique plus tel quel.

**P2, lecture :** l’export lit plusieurs tables successivement sans transaction de snapshot ; une mutation concurrente peut produire un JSON composite. La restauration écrit aussi SharedPreferences à l’intérieur d’une transaction SQL, sans transaction commune entre ces stockages. Aucun test de coupure à chacun des points d’écriture n’a été exécuté.

**P2, lecture :** sur natif, la photo sélectionnée est enregistrée comme chemin local ; certains affichages utilisent `NetworkImage`. Le backup conserve la référence plutôt que les octets du fichier natif, contrairement aux data URI web. La portabilité des photos après déplacement/réinstallation reste donc non garantie. Le sélecteur et le rendu natifs n’ont pas été exécutés ici.

### Synchronisation

Présence d’outbox durable, identifiants d’opération, révisions, générations, propriétaires, arbitrage explicite et protection d’une séance active concurrente. L’import transactionnel ne remplace pas un document ayant encore une opération locale pending. Les anciens snapshots sans clé d’active préservent l’état historique.

F02 et F05 montrent que ces protections ne couvrent pas toutes les mutations/refus. De plus, l’import stocke les champs du document sportif comme colonnes SQLite sans schéma de conversion exhaustif : des champs arbitraires acceptés par le serveur peuvent provoquer un refus d’insertion. Cette dernière variante est identifiée par lecture, sans sonde dédiée.

**PostgreSQL non validé aujourd’hui :** les tests utilisent SQLite. Les transactions serveur prennent des verrous de ligne PostgreSQL, mais concurrence multiworkers, latence, contention et reprise après incident Neon n’ont pas été testées. La création automatique du schéma via `create_all` ne remplace pas un historique de migrations de production.

## 9. Performances, résilience et fonctionnement hors ligne

- Les six vues SQL ont été exécutées dix fois sur 50 joueurs, 500 séances closes, 5 000 participations en mémoire. Médianes observées : classement 35,71 ms ; ratio 23,48 ms ; buteurs 11,94 ms ; passeurs 12,99 ms ; cartons 13,30 ms ; totaux 4,56 ms. Machine et charge du poste influencent ces valeurs. **Aucune conclusion sur la fluidité d’un téléphone n’en découle.**
- Build Flutter web : `main.dart.js` de 4 605 114 octets, SQLite wasm de 748 686 octets. Package statique environ 48 Mio non compressé, avec plusieurs moteurs CanvasKit et fontes. Le service worker précache toute la liste des ressources Flutter du package. C’est un coût de premier chargement/quota ; débit réel, compression CDN et éviction ne sont pas mesurés.
- Le code serveur envoie l’état complet du groupe à chaque synchronisation et calcule les totaux à la lecture. Pas d’index explicite supplémentaire ni pagination applicative dans les fichiers examinés. La cible de 500 séances peut rester raisonnable localement ; la croissance pluriannuelle partagée n’est pas caractérisée.
- Les vues/triggers locaux sont supprimés/recréés à chaque ouverture. Le temps de démarrage à froid, la batterie et les performances sur matériel modeste n’ont pas été mesurés.
- **P2, lecture :** `main()` attend préférences, DB et stockage sécurisé avant `runApp`, sans écran de récupération dédié autour de ces initialisations. Une erreur d’ouverture/migration peut donc empêcher l’entrée dans l’application ; F01 constitue un déclencheur concret.
- Transport : délais de connexion/réponse prévus, mais la lecture complète du corps intervient après la phase explicitement temporisée dans les deux transports. Pas de test de réponse infinie ou de coupure après en-têtes.
- Fonctionnement local sans compte confirmé. Les règles partagées exigent une identité non expirée pour écrire et une vérification en ligne pour copier des accès ; le 100 % hors ligne du CDC original ne peut pas être appliqué sans distinguer local et partagé.
- Aucune mesure actuelle des objectifs CDC « ouverture < 2 s » et « séance complète < 2 min » sur téléphone. La session manuelle d’audit, volontairement entrecoupée d’inspections, n’est pas un benchmark de saisie.

## 10. Livraison, exploitation et qualité du dépôt

| Sujet | État constaté |
|---|---|
| Branches | `staging`/`origin/staging` au même commit ; `main` distante reste ancienne. Aucun déploiement nouveau effectué. |
| Version produit | Flutter `1.0.0+1`, API `0.1.0` malgré l’évolution ; identification de version distribuée à clarifier. |
| Web | Vercel configuré sur le build universel ; compilation locale Linux réussie. Aucun contrôle de concordance du build public avec HEAD. |
| Android | Build release peut se signer avec la clé debug si la configuration privée manque. **P2 :** le succès d’un build n’est donc pas une preuve de signature de distribution correcte. Pas d’APK/AAB construit et installé aujourd’hui. |
| iOS | Projet présent ; pas de compilation Xcode, TestFlight ni appareil. Clés d’explication d’accès photo/caméra non repérées dans Info.plist alors que la galerie est utilisée : risque à confronter au plugin et au parcours natif, pas crash prouvé. |
| CI | Aucun `.github` ni pipeline versionné repéré. Le build Vercel exécute les unités web, pas automatiquement toute la suite Flutter, backend et navigateur. |
| Dépendances | Lockfiles npm et Dart présents. Python avec plages de versions ; `pip check` vert, avertissement Starlette/httpx. |
| Observabilité | Endpoint `/health` retourne un statut constant sans lecture DB ; **P2 :** il ne démontre pas la disponibilité métier de la base. Pas de métriques, suivi d’erreurs ni alerte métier configurés dans le code examiné. |
| Sauvegarde serveur | Neon/Render déclarés ; politique réelle de backup, rétention, restauration testée, RPO/RTO et supervision non vérifiés dans le compte d’hébergement. |
| Qualité | Modules métier structurés, scénarios et preuves RED/GREEN nombreux. Gros fichiers sensibles : service partagé 769 lignes, écran partagé 1 767, détail séance 1 453, API principale 724. Cela augmente le coût des revues croisées. |
| Tests | Bonne couverture nominale et des permissions. Pas de mesure de couverture actuelle ; nombre de tests ≠ exhaustivité. Pas de `integration_test` Flutter versionné repéré ; E2E présents côté navigateur. Les sondes de cet audit sont hors suite habituelle. |
| Documentation | README encore sur ancienne branche/portail ; tableau de rôles partagé contredit les droits sportifs actuels ; affirmations « non déployé/non commité » conservées dans des journaux désormais inclus dans l’historique. Les documents datés doivent être lus comme preuves de leur lot. |

## 11. Confrontation au CDC et couverture restante

Le CDC v1.1 vise un administrateur, un appareil Android, aucun compte/API/tournoi, sauvegarde automatique Supabase après clôture et migrations SQL numérotées. Le produit actuel ajoute multi-groupes, rôles, finances, API, synchronisation, arbitrage, tournoi, MVP et Flutter web. Les consignes persistantes actuelles ratifient notamment la parité web/mobile et prennent le mobile comme référence ; ces extensions ne sont pas classées comme défauts du seul fait de leur absence du CDC initial.

| Exigence initiale | État actuel |
|---|---|
| Joueurs, séances, score/statistiques, classement et ratio | Implémentés, régression et nominal navigateur exécutés. |
| Backup cloud automatique Supabase après clôture | **Absent** du mécanisme local examiné ; export manuel JSON et partage serveur constituent d’autres mécanismes. La synchronisation n’équivaut pas à un backup avec restauration garantie. |
| Refus des formats de sauvegarde futurs | **Non respecté**, F07. |
| Avertissement non bloquant écart buts/score | Produit actuel plus strict : clôture bloquante. Écart historique à maintenir dans un contrat produit actualisé. |
| Agrégats exclusivement SQL | Majoritairement SQL, calculs Dart présents pour MVP, finances et autres modèles ; architecture différente. |
| Migrations SQL numérotées, marqueur unique | Migrations Dart, version SQLite 8 et meta 1 ; F01. |
| Zéro perte après réinstallation | Non démontré ; dépend du backup manuel, des photos et des identifiants de reprise. |
| 50 joueurs, 500 séances fluides | Requêtes SQL synthétiques mesurées ; fluidité physique non testée. |
| <2 s démarrage et <2 min saisie | Non mesurés sur appareil. |
| Livraison APK validée sur appareil | Non exécutée aujourd’hui. |

Restent hors validation exécutée : Android/iOS physiques, Safari/WebKit, Firefox, tablette/paysage, lecteurs d’écran et clavier natifs, autorisations photo, presse-papiers/trousseau natifs, PWA installée, multi-onglets, corruption/quota/éviction de stockage, coupures à chaque étape d’export/restauration, concurrence PostgreSQL multiworkers, charge de production, restauration hébergeur, certificats/signatures réels, configuration publique et scan de CVE Python/Dart. Ces limites ne sont pas converties en bugs confirmés.

## 12. Conclusion de l’audit

Les fonctionnalités principales existent et le nominal testé est cohérent. Les **825 + 89 + 110 tests existants verts** coexistent avec des défauts d’intégrité reproduits : migration historique impossible, modifications locales de membres écrasées, documents sportifs invalides publiables. Le durcissement de ces chemins et de la reprise après refus constitue le principal écart entre un produit fonctionnel et une version fiable à diffuser. Les réserves d’accessibilité, de sécurité opérationnelle et de recette physique restent explicitement ouvertes.

Toutes les sondes, leurs résultats et les limites sont conservés dans ce dossier. Aucun correctif n’a été appliqué dans le cadre de l’audit.
