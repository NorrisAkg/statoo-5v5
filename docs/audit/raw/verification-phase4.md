# Vérification croisée — Phase 4 (14/11/2026)

Périmètre : tous les constats Critique et Majeur de 01-metier, 03-ui, 05-architecture, 06-securite, 07-donnees, 08-performance, 09-tests, 10-devops, 11-dependances (45 constats). Les rapports n'ont pas été modifiés.

Méthode : relecture de chaque preuve `fichier:ligne` (ligne vérifiée), des journaux de `docs/audit/raw/`, et reproductions locales isolées :
- `scratchpad/verif/serve95.py` + `dl.py` : instance **isolée** `create_app("sqlite:///:memory:")` sur 127.0.0.1:18095, lancée puis arrêtée. L'API partagée 18085 n'a pas été sollicitée (seulement un `GET /health` : 200).
- `scratchpad/verif/sec.py`, `sec6.py` : `TestClient` + SQLite mémoire (SEC-003, SEC-005, SEC-006).

Note : `docs/audit/raw/pytest.log` est désormais complet (`442 passed in 650.22s (0:10:50)`, l. 8) ; les mentions « pytest.log tronqué » des rapports sont caduques.

## Bilan

| Verdict | Nombre |
|---|---|
| Confirmé | 34 |
| Requalifié | 9 |
| Retiré | 0 |
| Non vérifiable | 2 |

## Verdicts

| ID | Sévérité initiale | Verdict | Sévérité finale | Justification (preuve relue) |
|---|---|---|---|---|
| MET-001 | Majeur | CONFIRMÉ | Majeur | `sessions_repository.dart:403-412` crée le point (tous les actifs, `rate`) à chaque enregistrement ; `sessions_provider.dart:769-776` `deleteSession` → `cancelSport` ; `shared_service.dart:515` `cancelled = true` puis suppression de la séance seule ; `financial_point.dart:158` et `finance.py:59` débitent `rate` sans regarder `cancelled`. La règle « échéance annulée conserve la cotisation » (`docs/shared-group-and-finance.md:58`) est voulue, mais l'UI annonce une suppression définitive (`session_detail_screen.dart:1367-1369`) : l'effet sur un brouillon supprimé n'est pas documenté. Majeur justifié (intégrité financière). |
| MET-002 | Majeur | CONFIRMÉ | Majeur | `session_close_rules.dart` : aucun bloqueur de minimum (seul `minCount` d'équilibre, l. 59) ; `main.py:955-965` refuse démarrage et clôture sous le minimum ; `web/domain.mjs:144-148` idem. Divergence de parité réelle. |
| MET-005 | Majeur | CONFIRMÉ | Majeur | Charge d'inscription Flutter sans `recovery_code` (`shared_group_screen.dart:159-169`) ; aucune occurrence de `recovery` dans `web/*.mjs` ; aucun appel à `/account/recovery-code` dans `mobile/lib` ni `web/` (grep). Seul `shared_service.dart:166-185` appelle `/auth/recover`. Aucun admin réel n'a donc de code : parcours ACCESS-07 inopérant. |
| MET-006 | Majeur | CONFIRMÉ | Majeur | `settings_screen.dart:95` (« modification par l'Admin dans la PWA ») ; `/sport-settings` et `/shared-access` appelés seulement par `web/app.mjs:2573` et `:2544` ; aucun appel Flutter (grep). Écart à la règle de parité d'`AGENTS.md` §1. Recoupe MET-005 pour le code de secours. |
| UI-001 | Majeur | REQUALIFIÉ | Mineur | Chiffres confirmés (432 `fontSize:` littéraux dans `mobile/lib` dont thème, 20 valeurs, 15 à 9/10 px). Mais c'est une incohérence de design et une dette de maintenabilité, pas une accessibilité bloquante : les tailles littérales restent soumises au `textScaler`. Relève de « Mineur : incohérence, dette ». |
| UI-002 | Majeur | REQUALIFIÉ | Mineur | Confirmé : `05-classement.jpg` montre « Bientôt disponible » (vu) ; `.claude/agents/design-fidelity.md:10-14` fait primer la capture. Impact limité à l'outillage interne (un agent de revue), aucun effet utilisateur ; `docs/design-system.md:8,12` corrige déjà la consigne. |
| ARC-001 | Majeur | CONFIRMÉ | Majeur | `create_app` de `main.py:244` à `:883` (~640 l.), 23 décorateurs de route (grep), `models.py` colonne `state` JSON unique. Dette qui freine l'évolution du backend. |
| ARC-002 | Majeur | CONFIRMÉ | Majeur | `main.py:282-284` et `:298-300` relus. Même cause racine que PERF-001 (Critique) : garder ici comme facette architecturale, à fusionner avec PERF-001/SEC-001/DAT-003/PERF-002 dans la synthèse. |
| ARC-003 | Majeur | CONFIRMÉ | Majeur | `shared_group_screen.dart:143-158` (`db.query('teams'/'players'/'meta')` dans l'écran) et `:1161-1171` (`service.request('PUT', …/members)`). Violation directe de la règle de dépendance d'`AGENTS.md` §4. |
| ARC-004 | Majeur | CONFIRMÉ | Majeur | Listes en dur relues : `shared_service.dart:39-48`, `shared_group_screen.dart:896-898`, `web/app.mjs:2824`, `main.py:518`. Duplication dans une zone déclarée à trois copies. |
| ARC-005 | Majeur | CONFIRMÉ | Majeur | `new_session_screen.dart` 1 316 l., `shared_service.dart` 1 003 l. (`wc -l`), dans les zones à risque d'`AGENTS.md` §6. Sévérité tenable au titre « dette qui freine une évolution » ; limite basse. |
| SEC-001 | Majeur | REQUALIFIÉ | Critique | Mécanisme relu (`main.py:298-300`, PBKDF2 600 000 it. `security.py:8,14` sous verrou). Reproduit sur l'instance isolée 18095 : **60 `POST /auth/login` non authentifiés** (groupe inexistant, donc même sans PBKDF2) → 54 timeouts, `/health` en timeout 15 s, toujours bloqué 20 s plus tard (rc 28), 44 threads en `futex_wait_queue`. Interblocage exploitable sans authentification = Critique selon l'échelle. Doublon de PERF-001 : fusionner. |
| SEC-002 | Majeur | NON VÉRIFIABLE | Majeur [déduit] | Code confirmé : `main.py:423`, `:445` sur `request.client.host` ; `uvicorn/config.py:363` défaut `127.0.0.1,::1` ; `render.yaml:8` sans `--forwarded-allow-ips`. L'effet dépend des variables et du proxy Render, invisibles depuis le dépôt. Compteurs non bornés : confirmé. Doublon d'OPS-007. |
| SEC-003 | Majeur | CONFIRMÉ | Majeur | `register` (`main.py:349-419`) sans `throttle` ; `members: list[dict]` max 1 000 (`:102`). Sonde `TestClient` : 22 créations consécutives → 22 × 201. |
| SEC-004 | Majeur | REQUALIFIÉ | Mineur | Code confirmé (`main.py:577-588` sans ressaisie, `:648-649` suppression du code de secours à la rétrogradation). Mais comportement voulu, livré (ACCESS-02) et testé (`test_co_admins.py:105,166,193`) ; le scénario suppose un co-admin malveillant ou un jeton admin déjà volé, qui donne de toute façon tous les droits. Reste un choix produit (question ouverte n° 5) : à rehausser si l'arbitrage exige une protection du créateur. |
| SEC-005 | Majeur | CONFIRMÉ | Majeur | `main.py:568-575`, `:675-684`, `:612-618` sans `throttle` (contrairement à `change_own_password`, `:595`). Sonde : 12 × 400 sur `shared-access/verify`, 8 × 400 sur `account/recovery-code`, aucun 429. Oracle sur le mot de passe d'un tiers. |
| SEC-006 | Majeur | REQUALIFIÉ | Mineur | Reproduit : `PUT roles ["ADMIN","PDT","TR"]` → 200, `POST /opening` → 200, `POST /opening/approve` par le même jeton → 200. Mais le cumul est explicitement admis par la doc (`docs/shared-group-and-finance.md:9`) et ne demande qu'un ADMIN ; c'est un choix de gouvernance en attente (question ouverte n° 5), pas une faille. À rehausser si la séparation des pouvoirs est retenue. |
| DAT-001 | Majeur | CONFIRMÉ | Majeur | `shared_group_screen.dart:1161-1171` publie les lignes `players` brutes ; `main.py:659-670` ne contrôle que `id`/`name` ; `main.py:509` renvoie `members` à tout compte. Photos (donnée personnelle) diffusées sans schéma. |
| DAT-002 | Majeur | CONFIRMÉ | Majeur | `main.py:822` (`operations`), `audit` append ; aucun retrait dans `state` (les seuls `.pop` portent sur `canonical_body`, `attempts`, `recovery`) ; `main.py:308-309` `with_for_update` + `deepcopy` à chaque requête. |
| DAT-003 | Majeur | CONFIRMÉ | Majeur | `main.py:284`, `:299` relus ; verrou indépendant du moteur, contredit le commentaire. Facette de PERF-001 : fusionner. |
| DAT-004 | Majeur | CONFIRMÉ | Majeur | Seule suppression d'`outbox_` : `shared_service.dart:385-389` (événement `pending` remplacé) ; aucune autre (grep). Écart avec `docs/outbox-sync.md:42`. |
| DAT-005 | Majeur | CONFIRMÉ | Majeur | `backup_service.dart:277-284` (repli sur `localTeams.first`) et `:322-345` (remappage vers le groupe cible). Documenté (`docs/backup.md:30-34`) mais l'écran ne transmet pas `targetTeamId` : la cible est arbitraire et le mélange de groupes irréversible. Majeur maintenu (multi-tenant). |
| DAT-006 | Majeur | CONFIRMÉ | Majeur | `app_database.dart:189-195` lève `StateError` ; `main.dart:29-30` ouvre la base avant `runApp` sans `try/catch` ; test MIG05 `null-team` (`database_migration_test.dart:310-312`). Fréquence faible et données préservées, mais l'application ne démarre plus pour l'utilisateur touché, sans recours : Majeur tenable. |
| DAT-007 | Majeur | CONFIRMÉ | Majeur | Aucune route `DELETE` (grep), `main.py:668-669` refuse la suppression de membre, `disconnect` n'efface aucune ligne SQLite. Droit à l'effacement non outillé. |
| PERF-001 | Critique | CONFIRMÉ | Critique | `fastapi/concurrency.py:29` (`run_in_threadpool(cm.__enter__)`, pool AnyIO `CapacityLimiter(40)`, `_asyncio.py:3162`) ; sortie sur limiteur propre (`:27`). Reproduit indépendamment sur 18095 avec 60 logins **non authentifiés** : gel définitif, `/health` inaccessible, 44 threads en `futex_wait_queue`, arrêt forcé nécessaire. `render.yaml:8` : un seul processus. Constat canonique de la famille verrou (SEC-001, ARC-002, DAT-003, PERF-002). Remarque : la reproduction initiale de l'auditeur visait l'API partagée 18085 (gelée puis relancée depuis ; `/health` répond 200 au moment de la vérification). |
| PERF-002 | Majeur | CONFIRMÉ | Majeur | Sérialisation inter-groupes cohérente avec le mécanisme relu et avec les mesures SEC-001. Doublon partiel de SEC-001/DAT-003. |
| PERF-003 | Majeur | CONFIRMÉ | Majeur | `shared_service.dart:243` (45 s), `:550` et `:656` (deux `GET /groups/$groupId` par cycle), `main.py:308-309`. Le chiffre de 6 Mo repose sur une taille de photo supposée (200 Ko), réaliste vu `maxBytes` 2 Mio. |
| PERF-004 | Majeur | REQUALIFIÉ | Mineur | Mesures faites sur `python http.server` sans compression ni cache ; en production, Vercel compresse en principe (non mesurable ici) et l'auditeur estime lui-même ~4,5 Mo. Le poids restant (CanvasKit + `main.dart.js`) est inhérent à Flutter web. Friction de premier chargement, pas de blocage avéré. |
| PERF-005 | Majeur | CONFIRMÉ | Majeur | `package-universal-web.mjs:36` n'exclut que `.`* et `.map` (donc `.symbols` et toutes les variantes wasm précachées) ; `install` → `addAll` de toute la liste. 47,5 Mo à chaque version : coût data réel pour les utilisateurs mobiles. |
| PERF-006 | Majeur | CONFIRMÉ | Majeur | `new_player_bottom_sheet.dart:38` `pickImage` sans `maxWidth`/`imageQuality` ; `player_photo.dart:103` stocke les octets d'origine ; `:120` ré-`encode` au décodage ; `player_avatar.dart:35`, `:83` `Image.memory` sans `cacheWidth`. Coûts sur appareil [déduit], mécanisme confirmé. |
| PERF-007 | Majeur | CONFIRMÉ | Majeur | `shared_service.dart:550/656` double GET et import, `:1001` `onChanged?.call()` inconditionnel. Coûts chiffrés [déduit]. |
| PERF-008 | Majeur | REQUALIFIÉ | Mineur | `pytest.log:8` : 442 tests en 650,22 s, confirmé ; `security.py:8,14` 600 000 it. en dur. Mais impact limité au confort développeur : les tests ciblés restent possibles, aucun risque utilisateur. Dette d'outillage = Mineur. |
| TST-001 | Majeur | CONFIRMÉ | Majeur | `.github` absent, aucun hook hors `*.sample`. Les 16 KO sur `staging` restent [déclaré] (non revérifié, pas de checkout). Doublon d'OPS-001. |
| TST-002 | Majeur | REQUALIFIÉ | Mineur | Absence d'outil de couverture confirmée. C'est une lacune d'outillage ; les trous concrets sont déjà portés par TST-003/TST-004. Pris isolément, ne crée pas de risque élevé. |
| TST-003 | Majeur | CONFIRMÉ | Majeur | `grep -rln "cancelSport\|deleteSession" mobile/test` → **aucun** fichier (le rapport citait `session_detail_kebab_menu_test.dart` : il ne contient même pas ces noms). Chemin destructif non testé, porteur du bug MET-001. |
| TST-004 | Majeur | CONFIRMÉ | Majeur | Une seule fixture partagée (`web/tests/fixtures/mobile-snapshot.json`), aucune pour finance ni rôles ; divergences MET-002/MET-007 coexistant avec des suites vertes. |
| TST-005 | Majeur | REQUALIFIÉ | Mineur | Absence de test 429 sur `/auth/login` confirmée (`grep 429` : seulement `test_change_password.py:168`, `test_recovery_code.py:245`). Mais deux des comportements visés (SEC-004, SEC-006) sont voulus et testés comme tels : pas de test négatif à écrire avant arbitrage. Reste une lacune ciblée. |
| OPS-001 | Majeur | CONFIRMÉ | Majeur | `render.yaml:7` (`pip install` seul), `build-universal-web.sh:12-17` (`build:web` puis `flutter build web` sans `flutter test`). Aucune CI. |
| OPS-002 | Majeur | CONFIRMÉ | Majeur | `main.py:277-279` ajoute des origines locales si `RENDER_GIT_BRANCH == "staging"`, et `docs/deploiement-d472c54-2026-10-17.md:3-4` constate cet effet sur l'API publique : le service public suit `staging`. Défauts vers la production : `shared_group_screen.dart:56-59`, `build-universal-web.sh:17`. L'état actuel du tableau de bord Render reste invisible, mais la preuve documentaire et le code suffisent. |
| OPS-003 | Majeur | CONFIRMÉ | Majeur | `grep -c logging backend/app/*.py` → 0 partout ; aucun `FlutterError.onError` / `runZonedGuarded` (`main.dart:24-36`). |
| OPS-004 | Majeur | CONFIRMÉ | Majeur | Absence de procédure dans le dépôt confirmée (`docs/deploiement-backend-pwa.md:38` seule mention). La rétention réelle de Neon n'est pas vérifiable : l'impact reste [déduit]. |
| OPS-005 | Majeur | CONFIRMÉ | Majeur | `backend/requirements.txt` à bornes larges, aucun `.python-version` / `runtime.txt`, pas de `PYTHON_VERSION` dans `render.yaml`. Doublon de DEP-001. |
| OPS-006 | Majeur | CONFIRMÉ | Majeur | `render.yaml:6` `plan: free`, `:8` un processus. Conditions du plan [déduit] ; aggravé par PERF-001 (pas de redémarrage garanti après gel). |
| OPS-007 | Majeur | NON VÉRIFIABLE | Majeur [déduit] | Doublon de SEC-002 : dépend de la configuration du proxy et des variables Render. Garder [déduit] et fusionner avec SEC-002. |
| DEP-001 | Majeur | CONFIRMÉ | Majeur | `requirements.txt:1-5` sans verrou ; `pip-audit.log` « No known vulnerabilities » contre `pip-freeze.txt` (`starlette==1.8.0`, `fastapi==0.143.2`). Doublon d'OPS-005. |

## Doublons à consolider dans la synthèse

- Verrou global : **PERF-001** (canonique, Critique) ← SEC-001 (Critique), ARC-002, DAT-003, PERF-002.
- Throttling derrière proxy : SEC-002 ← OPS-007.
- Lockfile backend : DEP-001 ← OPS-005.
- Absence de CI : OPS-001 ← TST-001.
- Suppression de séance : MET-001 ← TST-003 (absence de test).
- Code de secours : MET-005 ← MET-006 (partie recovery-code).
