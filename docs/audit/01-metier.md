# Audit Statoo — 01. Métier et produit

- **Domaine** : A — Métier et produit (vocabulaire, entités, règles sport/finance/rôles, cohérence doc ↔ code, cas limites, fonctionnalités incomplètes).
- **Date** : 14/11/2026. Arbre de travail de `fix/mobile-red-tests` (HEAD `2a9a3c7`, modifications non commitées incluses).
- **Méthode** : lecture statique de `mobile/lib/features/*/domain`, `sessions_provider.dart`, `sessions_repository.dart`, `finance/`, `shared_service.dart`, vues `v_*` de `app_database.dart`, `backend/app/main.py`, `backend/app/finance.py`, `web/domain.mjs`, `web/summary.mjs`, de la documentation métier et du CDC (`docs/Statoo_Cahier_des_Charges_v1.1.pdf`, extrait par `pdftotext`). **Exécuté** : un scénario API en mémoire (`create_app("sqlite:///:memory:")` + `TestClient`, script dans le scratchpad de la session, aucune écriture dans le dépôt ni en production) et une requête SQLite en mémoire pour la vue `v_group_totals`. Les journaux de `docs/audit/raw/` ont été consultés (`flutter-test.log` : « +1358: All tests passed! » ; `test-web.log` : 61 pass ; `pytest.log`, incomplet au moment de la rédaction, s'est terminé ensuite sur « 442 passed in 650.22s » — note de la session principale).
- **Limites** : aucun parcours UI exécuté ; le comportement de l'outbox après un refus 422 n'est pas rejoué (domaine synchro) ; la configuration réelle de production n'est pas visible.

## Synthèse

Le cœur des règles est cohérent : le calcul du résultat de tournoi, les rôles autorisés par domaine, la règle de l'échéance annulée et le barème du classement sont identiques dans les trois copies (Dart, Python, JS). En revanche, les trois copies divergent sur plusieurs contrôles bloquants. Le mobile, pourtant référence fonctionnelle, n'applique pas le minimum de joueurs à la clôture, alors que l'API refuse la même clôture (prouvé). La cohérence buts/score est bloquante en Dart et en Python, déduite en JS et non bloquante selon le CDC. Côté finance, « supprimer » une séance la transforme en échéance annulée qui **garde la cotisation due par tous les membres actifs**, alors que l'UI annonce une suppression définitive. Un brouillon abandonné crée aussi une dette. Le bug signalé sur `resolve` (obligations non mises à jour) est **confirmé par exécution**, mais son impact est faible. Plusieurs parcours annoncés « livrés » n'ont pas de client : le code de secours (ACCESS-01) n'est jamais créé à l'inscription, et le changement de son mot de passe (ACCESS-03), la régénération du code, la rotation de l'accès collectif et le réglage sport commun manquent dans Flutter. La documentation métier contredit le code sur les droits sportifs et sur le CDC.

**Note proposée : 3/5.** Les règles centrales sont bien testées côté mobile (1358 tests verts) et alignées sur l'essentiel. La note est plafonnée par quatre écarts majeurs : dette fantôme à la suppression, minimum non appliqué par la référence, parcours de récupération inopérant, parité Flutter incomplète. S'y ajoutent une dizaine de divergences mineures entre les trois copies.

## Tableau récapitulatif

| ID | Sévérité | Titre | Fichier principal | Effort |
|---|---|---|---|---|
| MET-001 | Majeur | Supprimer une séance (ou abandonner un brouillon) laisse une cotisation due à tous les membres | `mobile/lib/features/sessions/data/sessions_repository.dart` | M |
| MET-002 | Majeur | Minimum de joueurs non appliqué par le mobile à la clôture et au démarrage, refusé par l'API | `mobile/lib/features/sessions/domain/session_close_rules.dart` | S |
| MET-003 | Mineur | Cohérence buts/score : trois règles différentes, et le CDC la veut non bloquante | `web/domain.mjs` | S |
| MET-004 | Mineur | `resolve` ne met pas à jour `obligations` (confirmé) ; obligations figées à la première synchro | `backend/app/main.py` | S |
| MET-005 | Majeur | Le code de secours n'est jamais créé par un client : récupération ACCESS-07 inutilisable | `mobile/lib/features/shared/presentation/shared_group_screen.dart` | M |
| MET-006 | Majeur | Parité : réglage sport commun, rotation de l'accès collectif, mot de passe et code de secours absents de Flutter | `mobile/lib/features/settings/presentation/settings_screen.dart` | M |
| MET-007 | Mineur | Divergences de validation financière entre Dart, Python et JS | `mobile/lib/features/finance/domain/financial_point.dart` | S |
| MET-008 | Mineur | Messages d'erreur API financiers en anglais ou sans accents | `backend/app/finance.py` | XS |
| MET-009 | Mineur | Totaux du groupe : les tournois comptent dans les séances mais pour 0 but | `mobile/lib/core/data/app_database.dart` | XS |
| MET-010 | Mineur | Score classique initialisé à 0-0/DRAW : le bloqueur « score absent » ne se déclenche jamais | `mobile/lib/features/sessions/application/sessions_provider.dart` | S |
| MET-011 | Mineur | Poids MVP stockés par appareil, non synchronisés : joueur du mois différent selon l'appareil | `mobile/lib/features/ranking/data/ranking_repository.dart` | M |
| MET-012 | Mineur | Totaux financiers différents entre mobile et serveur/portail | `mobile/lib/features/finance/domain/financial_report.dart` | M |
| MET-013 | Mineur | Contrôle à deux personnes (soldes d'ouverture, arbitrage) contournable par cumul de rôles | `backend/app/main.py` | S |
| MET-014 | Mineur | Documentation métier contradictoire avec le code | `docs/shared-group-and-finance.md` | S |
| MET-015 | Mineur | Préremplissage des cotisations : les impayés sont encaissés par défaut, contrairement à la doc | `mobile/lib/features/finance/presentation/financial_point_screen.dart` | S |
| MET-016 | Mineur | Divergences sport secondaires (passes en brouillon, tri par nom, buts amicaux) | `web/summary.mjs` | S |
| MET-017 | Info | Code mort ou non branché dans le périmètre métier | `mobile/lib/features/finance/application/finance_providers.dart` | XS |

## Constats

### MET-001 — Supprimer une séance (ou abandonner un brouillon) laisse une cotisation due à tous les membres

- Sévérité : Majeur / Domaine : Métier, finance / Statut : confirmé
- Preuve :
  - Chaque enregistrement de séance, brouillon compris, crée un point financier au tarif pour **tous les joueurs actifs** : `mobile/lib/features/sessions/data/sessions_repository.dart:403-412` (`'rate': rate, 'cancelled': false, 'lines': members.map(...)`, `ConflictAlgorithm.ignore`).
  - « Supprimer » appelle `cancelSport` (`sessions_provider.dart:769-776`). Le point est conservé avec `point['cancelled'] = true` (`shared_service.dart:515`), seule la séance est supprimée (`shared_service.dart:529-533`).
  - Le calcul ignore l'annulation et débite le tarif : `financial_point.dart:150-161` (`previous.contributionBalance + line.contribution - point.rate`), `financial_report.dart:77-92`. Côté serveur, c'est le même calcul (`backend/app/finance.py:57-61`), et l'obligation est créée dès la première synchro sport, brouillon compris (`backend/app/main.py:816-820`).
  - L'UI annonce une suppression définitive : `session_detail_screen.dart:1366-1370` (« Ce match en cours sera définitivement supprimé »).
  - Exécution (API en mémoire) : séance synchronisée puis annulée → `finances.members.m4 = {'contribution_balance': -100, 'penalty_debt': 0}`.
- Impact : un brouillon créé par erreur puis supprimé, ou jamais joué, ajoute une dette de cotisation (100 F par défaut) à chaque membre actif, localement et sur le serveur. La règle « une échéance annulée conserve la cotisation due » (`docs/shared-group-and-finance.md:58`) est volontaire, mais elle s'applique ici à une action présentée comme une suppression. Le trésorier doit corriger à la main, sans outil prévu.
- Recommandation : arbitrer en produit la différence entre « séance annulée (cotisation due) » et « séance saisie par erreur (aucune échéance) ». Puis distinguer les deux actions dans l'UI et dans le protocole (statut ou drapeau dédié). Aligner Dart, Python et JS, écrire les tests d'abord et ne créer l'échéance qu'au démarrage ou à la clôture.
- Effort : M

### MET-002 — Minimum de joueurs non appliqué par le mobile à la clôture et au démarrage, refusé par l'API

- Sévérité : Majeur / Domaine : Métier, parité / Statut : confirmé
- Preuve :
  - Dart : `closeBlockers` n'a aucun bloqueur d'effectif minimal (`session_close_rules.dart:5-12`, `41-104`). `closeSession` (`sessions_provider.dart:559-618`), `startSession` (`276-304`) et `removeParticipation` (`697-756`) ne testent pas le minimum. Le seul contrôle est dans l'écran de création (`new_session_screen.dart:109-114`).
  - Python : refus à la clôture (`backend/app/main.py:963-965`) et au démarrage `is_active` (`955-962`, minimum et équilibre).
  - JS : refus à la clôture (`web/domain.mjs:144-148`, minimum lu dans `sport_settings`, `web/app.mjs:2035-2040`).
  - Exécution : clôture d'une séance à 5 joueurs via `/sync` → `422 {'detail': 'Sélectionnez au minimum 6 joueurs pour clôturer la séance'}`. Avec les mêmes données, `closeBlockers` Dart renvoie une liste vide.
- Impact : sur mobile, retirer un joueur après le démarrage (2 contre 3 reste équilibré) puis clôturer réussit localement. L'API refuse ensuite cette version, et le mobile et le serveur divergent durablement (séance CLOSED localement, DRAFT ou active côté serveur) [déduit pour l'état serveur]. La parité « aucune étape escamotée » n'est pas respectée.
- Recommandation : ajouter un bloqueur `belowMinimumPlayers` dans `closeBlockers`, lu depuis `minPlayersPerSessionProvider`. Appliquer le même contrôle dans `startSession` et `removeParticipation`, avec tests RED d'abord.
- Effort : S

### MET-003 — Cohérence buts/score : trois règles différentes, et le CDC la veut non bloquante

- Sévérité : Mineur / Domaine : Métier / Statut : confirmé
- Preuve :
  - CDC §5 : « Clôture non bloquante : un avertissement est affiché si la somme des buts des joueurs + non attribués diffère du score, mais la clôture reste possible. » (`docs/Statoo_Cahier_des_Charges_v1.1.pdf`, p. 3).
  - Dart : bloqueur `goalsMismatch` (`session_close_rules.dart:93-97`).
  - Python : refus « Buts et score incohérents » (`backend/app/main.py:986-991`).
  - JS : `unassigned_goals = score - goals` est **recalculé** et la valeur saisie est ignorée. Seul `goals > score` est refusé (`web/domain.mjs:135-141`).
- Impact : un même cas est bloqué sur mobile et sur l'API, mais corrigé en silence par le portail. L'écart au CDC n'est consigné dans aucune décision : `docs/business-rules.md:35` le décrit sans le justifier, alors que le CDC exige que toute contradiction soit « signalée explicitement ».
- Recommandation : trancher (bloquant ou avertissement), consigner la décision et aligner les trois copies. Dans le portail, ne plus écraser `unassigned_goals_*`.
- Effort : S

### MET-004 — `resolve` ne met pas à jour `obligations` (confirmé) ; obligations figées à la première synchro

- Sévérité : Mineur / Domaine : Métier, API / Statut : confirmé
- Preuve :
  - `/sync` met à jour le drapeau d'annulation de l'obligation : `backend/app/main.py:816-820`. `/resolve` applique le cycle de vie sportif (`840-845`) mais **pas** l'obligation (`827-858`).
  - Exécution : SG publie un DRAFT, VP envoie une version CANCELLED (conflit), PDT arbitre en faveur de VP → `doc status: CANCELLED | obligation cancelled: False`.
  - `setdefault` fige aussi `played_at`, `rate` et la liste des membres de l'obligation au premier envoi (`main.py:816-819`). Un changement de date ou d'effectif ultérieur n'y est pas reporté.
  - `resolve` (finance) recalcule les dettes sans les obligations (`main.py:848`), contrairement à `/sync` (`main.py:772`, `financial_points`). C'est sans effet aujourd'hui, car les obligations n'ont aucune pénalité.
- Impact : limité. `totals` n'utilise pas `cancelled` (`finance.py:54-63`), et le mobile n'importe une obligation qu'une fois (`shared_service.dart:847-850`, `ConflictAlgorithm.ignore`). Après arbitrage, l'échéance est pourtant présentée comme non annulée : un trésorier peut saisir des encaissements que `validate_financial_roster` refusera (`main.py:231-233`) [déduit].
- Recommandation : extraire dans une fonction la mise à jour de l'obligation après acceptation d'une version sportive, et l'appeler depuis `/sync` et `/resolve`. Réutiliser `financial_points` dans `resolve`. Tests de non-régression : arbitrage vers une annulation, puis vers une restauration.
- Effort : S

### MET-005 — Le code de secours n'est jamais créé par un client : récupération ACCESS-07 inutilisable

- Sévérité : Majeur / Domaine : Produit, parcours / Statut : confirmé
- Preuve :
  - L'API n'accepte un code de secours qu'à l'inscription (`backend/app/main.py:101`, `384-392`) ou via `PUT /groups/{g}/account/recovery-code` (`612-630`).
  - La charge d'inscription Flutter n'envoie pas `recovery_code` (`shared_group_screen.dart:159-169`). Aucune occurrence de `recovery` dans `web/*.mjs`.
  - `RecoveryCodeGenerator.generate()` ne sert qu'à produire le **nouveau** code pendant une récupération (`recovery_controller.dart:114`).
  - Aucun appel à `/account/recovery-code` ni à `/account/password` dans `mobile/lib` ou `web/` (recherche textuelle).
  - Le backlog marque ACCESS-01, ACCESS-03 et ACCESS-07 « livrés » (`docs/ai/BACKLOG.md:94`, `106`, `169`).
- Impact : un groupe créé depuis Flutter ou le portail n'a pas de code de secours. Le parcours « Code de secours » de l'écran d'entrée (ACCESS-07) échoue donc pour tout administrateur réel [déduit : `recover` compare au hash factice]. Un admin qui oublie son mot de passe dépend d'un co-admin.
- Recommandation : générer et afficher le code à la création du groupe (ACCESS-05), et ajouter dans les réglages Flutter la régénération et le changement de mot de passe. Corriger le statut du backlog : « backend livré, client absent ».
- Effort : M

### MET-006 — Parité : réglage sport commun, rotation de l'accès collectif, mot de passe et code de secours absents de Flutter

- Sévérité : Majeur / Domaine : Produit, parité / Statut : confirmé
- Preuve :
  - Dans un groupe partagé, le minimum de joueurs est verrouillé dans Flutter avec le message « Règle commune du groupe : modification par l'Admin dans la PWA » (`settings_screen.dart:40-41`, `94-95`, `111`). `PUT /sport-settings` n'est appelé que par le portail (`web/app.mjs:2573`).
  - `PUT /shared-access` (rotation de l'accès collectif, `main.py:686-700`) n'est appelé que par le portail (`web/app.mjs:2544`). Flutter ne fait que la vérification (`collective_access.dart:82`).
  - `POST /account/password` (`main.py:590`) et `PUT /account/recovery-code` (`main.py:612`) n'ont aucun appelant.
- Impact : la règle `AGENTS.md` §1 (« Mobile = référence », aucune étape escamotée) n'est pas tenue. Ces opérations d'administration dépendent du portail historique, déclaré gelé, ou n'existent pas côté client.
- Recommandation : planifier ces écrans dans Flutter (lot ACCESS ou PARITY) avant de retirer le portail, et tenir une matrice « endpoint × client » à jour.
- Effort : M

### MET-007 — Divergences de validation financière entre Dart, Python et JS

- Sévérité : Mineur / Domaine : Métier, finance / Statut : confirmé
- Preuve :

| Règle | Dart (mobile) | Python (API) | JS (portail) |
|---|---|---|---|
| Motif obligatoire pour une pénalité due | Non (`financial_point.dart:91-119` ; aucun contrôle dans `financial_point_screen.dart:357-407`) | Non (`finance.py:13`, défaut `""`) | **Oui** (`web/domain.mjs:189-190`) |
| Liste complète des membres de l'échéance | Non, seuls les membres inconnus sont refusés (`finance_repository.dart:121-128`) | **Oui** (`main.py:225-230`) | **Oui** (`web/domain.mjs:178-185`) |
| Paiement de pénalité supérieur à la dette | **Refusé** (`finance_repository.dart:146-163`) | **Refusé** (`main.py:773-775`) | Non contrôlé (`web/domain.mjs:174-207`) |
| Plafond 10^12 par montant | **Absent** (`financial_point.dart:92-108`) | `le=10**12` (`finance.py:10-12`, `20`, `26`) | `max(1e12)` (`web/validation.mjs:14-18`) |

- Impact : une saisie acceptée localement peut être refusée par l'API (422), par exemple si un membre a été ajouté ou archivé entre la création du point et sa validation, ou si un montant est démesuré. Le motif de pénalité, exigé par le portail, est facultatif sur mobile, d'où des pénalités sans justification.
- Recommandation : une seule table de règles, partagée par des tests de parité (fixtures communes Dart/Python/JS). Exiger le motif partout, ou nulle part, après arbitrage.
- Effort : S

### MET-008 — Messages d'erreur API financiers en anglais ou sans accents

- Sévérité : Mineur / Domaine : Métier, convention / Statut : confirmé
- Preuve : `backend/app/finance.py:42` (« Unknown or duplicate member »), `44` (« Duplicate movement »), `47` (« Cancelled periods have contributions due… »), renvoyés tels quels au client par `main.py:778-779`. Ailleurs, des messages sont sans accents : `main.py:230` (« echeance »), `233` (« seance annulee »).
- Impact : l'utilisateur voit de l'anglais ou un français dégradé, contraire à la convention (« français pour les messages d'erreur API », `CLAUDE.md`).
- Recommandation : traduire et accentuer ces messages, et ajouter un test qui vérifie la langue des messages 422.
- Effort : XS

### MET-009 — Totaux du groupe : les tournois comptent dans les séances mais pour 0 but

- Sévérité : Mineur / Domaine : Statistiques / Statut : confirmé
- Preuve : `app_database.dart:605` (`score_a + score_b + COALESCE(score_c, 0)`). Les tournois ont `score_a = score_b = NULL` (`sessions_provider.dart:225-226` ; `sessions_repository.dart:580-582`, « Only the two-team format keeps a running match score »), donc la somme vaut NULL et elle est ignorée par `SUM`. Ces séances sont pourtant comptées dans `total_sessions` (`602`) et dans la moyenne (`638`). Reproduction SQLite : une séance 3-2 et un tournoi → `(2 séances, 5 buts)`, moyenne 2,5.
- Impact : avec des tournois, le total de buts et la moyenne par séance du groupe sont sous-estimés. `unassigned_goals_difference` (`643`) est faussé, car les buts joueurs des tournois sont comptés.
- Recommandation : pour les tournois, compter les buts à partir des participations et des buts non attribués, ou exclure les tournois de la moyenne. Ajouter un test de vue.
- Effort : XS

### MET-010 — Score classique initialisé à 0-0/DRAW : le bloqueur « score absent » ne se déclenche jamais

- Sévérité : Mineur / Domaine : Métier / Statut : confirmé
- Preuve : `sessions_provider.dart:223-233` (`TODO(cdc)` : `scoreA: 0, scoreB: 0, result: MatchResult.draw`) ; `startSession` remet aussi 0-0 (`289-299`). `hasScore` ne teste que la présence des valeurs (`session_close_rules.dart:34-39`). Le CDC §5 exige un « score renseigné ». La question est ouverte (`docs/decisions-and-risks.md:14`, `docs/onboarding/questions-ouvertes.md:10`) depuis le commit `ebadbc7` du 26/09/2026.
- Impact : une séance classique peut être clôturée sans aucune saisie et compter comme un nul classé (1 point chacun). `CloseBlocker.missingScore` ne sert plus que pour les tournois.
- Recommandation : arbitrer. Si 0-0 reste le défaut, demander une confirmation explicite à la clôture d'un 0-0 sans aucun événement saisi, et retirer le `TODO`.
- Effort : S

### MET-011 — Poids MVP stockés par appareil, non synchronisés : joueur du mois différent selon l'appareil

- Sévérité : Mineur / Domaine : Classement / Statut : confirmé
- Preuve : clé locale `mvp_weights_<teamId>` dans `meta` (`ranking_repository.dart:25`, `421-440`). Aucune occurrence de `mvp` dans `mobile/lib/features/shared/` ni dans `backend/app/`. Le calcul SQL utilise ces poids (`ranking_repository.dart:291-323`). La documentation dit « poids configurables par groupe » (`docs/business-rules.md:49`).
- Impact : dans un groupe partagé, deux appareils aux poids différents désignent des joueurs du mois différents. Par ailleurs, le paramètre `drawPoints` de `MvpCalculator.calculateMatchScore` (`mvp_calculator.dart:19-25`) n'est pas utilisé par le calcul réel, et la fonction ne sert qu'à l'exemple de la fiche de règles (`mvp_rules_bottom_sheet.dart:57`).
- Recommandation : soit stocker les poids dans `sport_settings` côté API (droits ADMIN), soit documenter qu'ils sont propres à l'appareil. Supprimer le paramètre inutilisé.
- Effort : M

### MET-012 — Totaux financiers différents entre mobile et serveur/portail

- Sévérité : Mineur / Domaine : Finance, parité / Statut : confirmé (les écarts chiffrés sont [déduits])
- Preuve :
  - Mobile : un point est créé dès l'enregistrement d'un brouillon, même non démarré ni synchronisé (`sessions_repository.dart:403-412`). Le serveur ne crée l'obligation qu'à la première synchro sport (`main.py:816`), et `createDraftSession` ne synchronise que si la séance démarre (`sessions_provider.dart:269-271`).
  - Mobile : le bilan exclut les échéances postérieures à aujourd'hui (`financial_report.dart:77`). Serveur : `totals` les inclut toutes (`finance.py:54-63`), et le portail affiche ces totaux serveur (`web/app.mjs:1201`, `1339-1347`).
  - Le point local reprend le tarif `finance_rate_<team>` (`sessions_repository.dart:403-404`), l'obligation serveur celui de `financial_settings` au moment de la synchro (`main.py:817`).
- Impact : la caisse et les dettes affichées diffèrent entre Flutter et le portail (brouillons non synchronisés, séances programmées à l'avance).
- Recommandation : définir une règle unique pour la date d'effet et la création d'échéance, et la tester en parité.
- Effort : M

### MET-013 — Contrôle à deux personnes (soldes d'ouverture, arbitrage) contournable par cumul de rôles

- Sévérité : Mineur / Domaine : Rôles, gouvernance / Statut : confirmé
- Preuve : les rôles se cumulent (`check_roles`, `main.py:335-338`). L'unicité ne vaut qu'entre comptes (`main.py:548`, `640-645`), et la doc l'admet (« Les titulaires peuvent cumuler des rôles », `docs/shared-group-and-finance.md:9`). `approve_opening` n'enregistre ni ne compare l'auteur de la proposition (`main.py:720-750`). `resolve` ne vérifie pas que l'arbitre n'est pas l'auteur d'une version concurrente (`main.py:827-858`).
- Impact : un même compte TR+PDT peut proposer puis approuver ses propres soldes initiaux, ou arbitrer un conflit en sa faveur. La séparation « proposé par TR/TGA, approuvé par PDT/VP » n'est donc pas garantie.
- Recommandation : enregistrer `proposed_by` et refuser l'auto-approbation, de même que l'arbitrage par l'auteur d'une version. Sinon, interdire le cumul TR/TGA avec PDT/VP.
- Effort : S

### MET-014 — Documentation métier contradictoire avec le code

- Sévérité : Mineur / Domaine : Documentation / Statut : confirmé
- Preuve :
  - `docs/shared-group-and-finance.md:15-21` : seuls SG/SGA écrivent le sport, et « ADMIN ne donne pas implicitement les droits sportifs ». Le code autorise ADMIN, PDT, VP, SG et SGA (`main.py:33`, `shared_service.dart:39-48`, `web/domain.mjs:45`).
  - `AGENTS.md` §5 (« score absent, doublon, déséquilibre ») omet le bloqueur `goalsMismatch`, l'auto-passe et le minimum de joueurs appliqué par l'API. `AGENTS.md:50` parle de « calculs de reliquat », terme absent du code. `docs/ai/GLOSSAIRE.md:17` le reprend, avec un « solde initial » qui ne figure pas dans un point financier.
  - `docs/ai/GLOSSAIRE.md:8` présente `CANCELLED` comme un statut de séance. L'enum Dart n'a que `draft` et `closed` (`session.dart:6`), et une séance reçue annulée est supprimée localement (`shared_service.dart:939-944`).
  - Le CDC exclut explicitement les tournois, le multi-utilisateur, les rôles et l'API (CDC §2) : aucune mise à jour du CDC ne trace ces évolutions.
  - `docs/domain/glossaire.md:88` marque les libellés de rôles « [déduit] ». Ils sont confirmés par `web/domain.mjs:20-30`.
- Impact : un nouvel intervenant appliquerait de mauvais droits ou de mauvaises règles de clôture.
- Recommandation : corriger le tableau des rôles, compléter `AGENTS.md` §5, remplacer « reliquat » par « solde, avance ou dette », et marquer `docs/ai/GLOSSAIRE.md` comme remplacé par `docs/domain/glossaire.md`.
- Effort : S

### MET-015 — Préremplissage des cotisations : les impayés sont encaissés par défaut, contrairement à la doc

- Sévérité : Mineur / Domaine : Finance, UX / Statut : confirmé
- Preuve : à la première ouverture, chaque cotisation à 0 est remplie avec le tarif dans le champ lui-même (`financial_point_screen.dart:139-156`, `_contributions[...].text = '${point.rate}'`), absents compris. Un simple avertissement invite à « effacer les montants des impayés » (`701-704`). La doc affirme pourtant que « les montants affichés dans les champs vides sont indicatifs et ne constituent pas des encaissements » (`docs/shared-group-and-finance.md:73`).
- Impact : un point validé sans relecture enregistre en caisse des cotisations non reçues. La caisse est surévaluée et les dettes masquées.
- Recommandation : afficher le tarif en indication (`hintText`), sans valeur saisie, ou demander une confirmation explicite qui liste les membres préremplis. Aligner la doc.
- Effort : S

### MET-016 — Divergences sport secondaires (passes en brouillon, tri par nom, buts amicaux)

- Sévérité : Mineur / Domaine : Métier, classement / Statut : confirmé
- Preuve :
  - Passes : JS refuse des passes incohérentes dès l'enregistrement d'un brouillon (`web/domain.mjs:137-138`, quel que soit le statut). Dart et Python ne le font qu'à la clôture (`session_close_rules.dart:98-103`, `main.py:992-993`).
  - Départage par nom : collation binaire SQLite (`app_database.dart:448`) et `String.compareTo` (`ranking_repository.dart:390`) d'un côté, `localeCompare(…, "fr")` de l'autre (`web/summary.mjs:46`). Les noms accentués ou en minuscule ne sont pas classés pareil.
  - Buts du classement général : séances amicales incluses (`app_database.dart:441-442`). Classement mensuel : séances classées seulement (`ranking_repository.dart:82`).
- Impact : à égalité, le classement diffère entre portail et mobile. Les colonnes buts et passes changent de sens entre vue générale et vue mensuelle.
- Recommandation : choisir un tri par nom insensible à la casse et aux accents, et le même périmètre de buts dans les deux vues. L'ajouter aux tests de parité.
- Effort : S

### MET-017 — Code mort ou non branché dans le périmètre métier

- Sévérité : Info / Domaine : Dette / Statut : confirmé
- Preuve :
  - `financialTotalsProvider` (`finance_providers.dart:33`) n'est lu par aucun écran, seulement invalidé (`main.dart:107`, `sessions_provider.dart:164`…). L'UI utilise `financialReportProvider` (`finances_screen.dart:935`).
  - `StatsExportService` et `StandingsCsvFormatter` (FEAT-01, fichiers non suivis) ne sont importés nulle part ailleurs.
  - `late_penalty` ne sert que de valeur proposée dans l'écran du point (`financial_point_screen.dart:796`), aucun calcul ne l'utilise.
- Impact : maintenance, et deux calculs de totaux qui peuvent diverger.
- Recommandation : supprimer `financialTotalsProvider` ou l'utiliser. Brancher ou retirer l'export (le CDC v1.1 l'exclut, le backlog le prévoit).
- Effort : XS

## Hypothèses à vérifier

1. **Fuseaux horaires** : `played_at` est une date locale sans décalage côté mobile (`toIso8601String()` d'un `DateTime` local, `sessions_repository.dart:409`). Le mois du MVP et du classement mensuel est tiré de `substr(played_at, 1, 7)` (`ranking_repository.dart:254`, `285`, `321`). L'API accepte `Z` et les décalages (`main.py:914-916`). Si un client envoie une date UTC, une séance de fin de mois change de mois. La comparaison avec la date d'ouverture diffère aussi : chaîne côté Python (`finance.py:55`), `DateTime.isBefore` côté Dart (`financial_point.dart:151`). À tester avec une séance à 23h30 UTC le dernier jour du mois.
2. **Refus 422 d'une clôture (MET-002)** : on ne sait pas si l'outbox laisse `active_session_id` bloqué côté serveur et empêche de démarrer la séance suivante (`main.py:894-897`). À rejouer dans le domaine synchro.
3. **Effectif de l'obligation et lignes locales** : si un joueur est ajouté ou archivé entre la création locale du point (création du brouillon) et la première synchro sport (création de l'obligation), le point du trésorier est refusé (`main.py:228-230`) [déduit].
4. **Joueur du mois en cours** : `getPlayerOfTheMonth` sans mois retient le mois le plus récent, même entamé (`ranking_repository.dart:458-466`). Avec une seule séance, le premier joueur du mois est désigné après un seul match. Le comportement attendu est à confirmer en produit.
5. **Montants non numériques** : `int.tryParse(c.text) ?? 0` (`financial_point_screen.dart:177`) transforme silencieusement une saisie invalide en 0 si le champ n'impose pas les chiffres seuls. À vérifier sur les champs de cotisation.

## Points positifs (Info)

- **Résultat de tournoi identique dans les trois copies** : `computeTournamentResult` (`session_close_rules.dart:23-32`), `main.py:968-975`, `web/domain.mjs:156-167`. Mêmes cas d'égalité (AB, BC, AC, ALL), et un résultat absent si toutes les victoires valent 0.
- **Rôles par domaine alignés** : sport = ADMIN/PDT/VP/SG/SGA, finance = TR/TGA, réglages financiers = ADMIN/TR/TGA (`main.py:33`, `705` ; `shared_service.dart:39-48` ; `web/domain.mjs:41-50`).
- **Échéance annulée** : même règle dans les trois copies (cotisation due, aucun mouvement ni pénalité) : `financial_point.dart:110-118`, `finance.py:45-47`, `web/domain.mjs:199-205`.
- **Barème identique** entre la vue SQL et le portail : classique 3/1/0, nul de tournoi selon `draw_points` (`app_database.dart:384-396`, `web/summary.mjs:27-38`). Départage points > victoires > matchs > nom partout.
- **Montants entiers et non négatifs** partout (`StrictInt ge=0` côté Python, `int` en Dart, `z.number().int().min(0)` en JS) : aucun risque d'arrondi flottant.
- **Clôture atomique** relue en transaction, avec contrôle de concurrence (`sessions_provider.dart:557-618`), et 1358 tests mobiles verts (`docs/audit/raw/flutter-test.log`).

## Renvois vers d'autres domaines

- Synchronisation et outbox : effet d'un refus 422 de clôture sur la séance active serveur (hypothèse 2) ; import des obligations en `ConflictAlgorithm.ignore` (`shared_service.dart:847-850`), qui empêche toute mise à jour ultérieure.
- Accès et sécurité : code de secours jamais émis (MET-005) ; limitation de débit et verrou global (`main.py:284`, `298-300`) à traiter dans le domaine API.
- Documentation : `docs/ai/BACKLOG.md:88-89` décrit encore ADMIN comme rôle singulier et l'absence de changement de mot de passe, ce que ACCESS-02 et ACCESS-03 ont modifié.
- Tests : `docs/audit/raw/pytest.log` était incomplet lors de la rédaction ; il s'est terminé ensuite sur « 442 passed in 650.22s » (correction de la session principale, Phase 4).

## Vérification croisée (Phase 4, 14/11/2026)

Tous les constats Critique et Majeur de ce rapport ont été relus et **confirmés** (aucun retrait, aucune requalification). Verdicts : [raw/verification-phase4.md](raw/verification-phase4.md).
