# Audit Statoo — 08. Performance

- **Domaine** : performance du livrable Flutter web, du backend FastAPI, de l'app mobile (SQLite, synchronisation, images), du portail `/portal/` et des suites de tests.
- **Date** : 14/11/2026.
- **Méthode** : lecture du code, plus mesures exécutées en local :
  - backend : scripts Python `http.client` contre l'API isolée `http://127.0.0.1:18085` (`web/tests/serve.py`, SQLite en mémoire, un processus uvicorn) ; 16 groupes de test créés ;
  - Flutter web : Playwright + Chrome (`channel: 'chrome'`), session CDP (`Network.enable`, `Network.setCacheDisabled`, `Network.emulateNetworkConditions`), viewport 393x852, contexte vierge, requêtes hors `127.0.0.1` bloquées et journalisées. Serveur `python http.server` sur `127.0.0.1:18090` (`mobile/build/web`, build release du 14/11 avec `STATOO_API=http://127.0.0.1:18085`) ;
  - profils réseau émulés (page uniquement) : **aucun** (loopback), **« 4G »** = latence 170 ms, 9 Mbit/s descendant, 1,5 Mbit/s montant, **« Fast 3G »** = latence 563 ms, 1,44 Mbit/s descendant, 0,675 Mbit/s montant ;
  - « premier rendu utile » = événement `flutter-first-frame` émis par le moteur Flutter (premier écran de l'app, pas l'écran de chargement HTML).
- **Limites** : machine de développement locale, réseau loopback, pas de mesure sur Vercel, Render ni Neon (interdit). Le serveur local ne compresse pas et n'envoie aucun `Cache-Control` : ces mesures représentent le pire cas, pas Vercel. L'émulation réseau CDP ne s'applique pas au service worker (cible distincte) : le préchargement du SW n'a été mesuré que sans bridage. Volumétrie mobile non mesurée sur appareil (pas d'émulateur lancé) : les constats mobiles sont des **risques identifiés par analyse** sauf mention contraire. Lighthouse non disponible.
- **Incident pendant l'audit** : la mesure de PERF-001 a **bloqué durablement l'API locale partagée** (`127.0.0.1:18085`, PID 183806, toujours bloquée à la rédaction). Elle doit être relancée par la session principale ; les autres domaines qui l'utilisent (B, D) peuvent avoir rencontré des délais d’attente depuis cette mesure.

## Synthèse

Le point le plus grave est un **interblocage** du backend : le verrou global `threading.Lock` est pris dans une dépendance FastAPI exécutée dans le pool de 40 threads d'AnyIO. Dès qu'une quarantaine de requêtes concurrentes attendent ce verrou, le détenteur ne trouve plus de thread pour exécuter `authenticate` puis la route : **l'API ne répond plus du tout, `/health` compris, jusqu'au redémarrage du processus**. C'est reproduit en local avec 60 requêtes simultanées. Hors interblocage, le verrou sérialise tous les groupes : 4 créations de groupe en parallèle font attendre 3,3 s une lecture d'un autre groupe. Le coût d'une requête authentifiée croît avec l'agrégat JSON (`deepcopy`) : un groupe avec 30 photos pèse 6 Mo par snapshot, 105 ms serveur, et l'app le télécharge deux fois toutes les 45 s.

Côté Flutter web, le premier chargement télécharge **11,9 Mo non compressés en 21 requêtes**. Premier écran à 2,0 s en loopback, **11,9 s en 4G émulée et 66 s en Fast 3G**. Le service worker de production précache en plus **47,5 Mo** (52 fichiers), dont 8,6 Mo de fichiers `.symbols` de débogage et 6 variantes du moteur de rendu dont une seule sert. L'erreur 404 au démarrage vient de `sw.js`, absent du build Flutter brut (il n'est généré qu'au packaging Vercel) : c'est un artefact local. Une police est demandée à `fonts.gstatic.com` malgré `--no-web-resources-cdn`.

Côté mobile : chaque synchronisation réécrit toutes les séances et participations du groupe puis invalide 19 providers. Les photos sont stockées en taille d'origine (jusqu'à 2 Mio), puis décodées et revalidées sur le thread UI à chaque affichage d'avatar. La suite pytest (10 min 50) est ralentie par le PBKDF2 à 600 000 itérations, non paramétrable en test, ce qui freine le TDD exigé par `AGENTS.md`.

**Note proposée : 2/5.** Les fondations sont correctes : synchronisation hors ligne, tree-shaking des icônes Material, `ListView.builder` sur les listes principales, `/health` sans verrou. Mais le backend peut être gelé par une charge banale ou malveillante, l'agrégat unique rend chaque requête proportionnelle à l'historique, et le premier chargement web est lourd sur réseau mobile.

## Tableau récapitulatif

| ID | Sévérité | Titre | Fichier principal | Effort |
|---|---|---|---|---|
| PERF-001 | Critique | Interblocage définitif de l'API dès ~40 requêtes concurrentes (verrou global + pool de threads) | `backend/app/main.py:298-300` | S |
| PERF-002 | Majeur | Verrou global : sérialisation mesurée entre groupes, chiffres complémentaires à SEC-001/DAT-003 | `backend/app/main.py:284` | M |
| PERF-003 | Majeur | Coût de chaque requête proportionnel à l'agrégat `groups.state` ; snapshot de 6 Mo téléchargé 2 fois toutes les 45 s | `backend/app/main.py:309`, `mobile/lib/features/shared/data/shared_service.dart:243` | L |
| PERF-004 | Mineur (requalifié, était Majeur) | Premier chargement Flutter web : 11,9 Mo, premier écran à 66 s en Fast 3G et 11,9 s en 4G | `mobile/build/web` | M |
| PERF-005 | Majeur | Le service worker de production précache 47,5 Mo, dont `.symbols` et 6 variantes du moteur de rendu | `scripts/package-universal-web.mjs:33-53` | S |
| PERF-006 | Majeur | Photos stockées en taille d'origine, décodées en pleine résolution et revalidées sur le thread UI à chaque avatar | `mobile/lib/core/media/player_photo.dart:47-103` | M |
| PERF-007 | Majeur | Synchronisation toutes les 45 s : double import complet, réécriture de toutes les participations, 19 invalidations | `mobile/lib/features/shared/data/shared_service.dart:542-680` | M |
| PERF-008 | Mineur (requalifié, était Majeur) | Suite pytest de 10 min 50 dominée par le PBKDF2 non paramétrable : frein au TDD | `backend/app/security.py:8,14` | S |
| PERF-009 | Mineur | Police de repli téléchargée depuis `fonts.gstatic.com` au démarrage | moteur Flutter web | XS |
| PERF-010 | Mineur | Client HTTP recréé à chaque requête, lecture du corps hors délai, décodage JSON sur le thread UI | `mobile/lib/core/data/shared_http_native.dart:13-20` | S |
| PERF-011 | Mineur | Listes non virtualisées (joueurs, finances) et écritures SQLite unitaires en boucle | `mobile/lib/features/players/presentation/players_screen.dart:105` | S |
| PERF-012 | Mineur | Journal des stats en direct réécrit en entier à chaque but (coût quadratique) | `mobile/lib/features/sessions/data/live_stats_repository.dart:240-291` | S |
| PERF-013 | Mineur | Poppins Regular téléchargée deux fois ; `remix.ttf` réduite de 18 % seulement | `mobile/web/pwa-shell.css:2-4` | XS |
| PERF-014 | Mineur | `vercel.json` sans en-têtes de cache : aucune mise en cache longue des ressources du moteur | `vercel.json` | XS |
| PERF-015 | Mineur | Service worker du portail : version de cache manuelle et 1,2 Mo d'images précachées | `web/sw.js:3,20-23` | XS |
| PERF-016 | Info | L'erreur 404 au démarrage est `sw.js`, absent du build Flutter non packagé | `mobile/web/app-shell.js:169` | XS |

---

### PERF-001 — Interblocage définitif de l'API dès ~40 requêtes concurrentes (verrou global + pool de threads)
- Sévérité : Critique / Domaine : disponibilité backend / Statut : confirmé (reproduit en local)
- Preuve :
  - `backend/app/main.py:284` `lock = threading.Lock()` ; `:298-300` `def db(): with lock, Session(engine) as session, session.begin(): yield session`. `authenticate` (l. 302) dépend de `db`, et toutes les routes sont des fonctions synchrones (`def`).
  - FastAPI exécute l'entrée d'une dépendance générateur synchrone dans le pool par défaut d'AnyIO, limité à 40 threads (`backend/.venv/.../fastapi/concurrency.py:29` `yield await run_in_threadpool(cm.__enter__)` ; `anyio/_backends/_asyncio.py:3162` `CapacityLimiter(40)`). Seule la sortie a son propre limiteur (`concurrency.py:27`). La requête qui détient le verrou doit encore obtenir un thread du même pool pour `authenticate` puis pour la route. Si les 40 threads sont tous bloqués dans `db()` en attente du verrou, aucun thread ne se libère : interblocage.
  - Reproduction : `scratchpad/perf/bench2.py`. Groupe de 30 membres avec photo (snapshot de 105 ms), puis **60 `GET /groups/{id}` simultanés**, puis `GET /health` 0,3 s après. Résultat : `/health` ne répond pas en 300 s (`TimeoutError: timed out`), et 10 min plus tard `curl -m 5 http://127.0.0.1:18085/health` échoue toujours (code 28). Processus : CPU figé (`utime` 3169 → 3170 en 5 s), 45 threads, dont **44 en `futex_wait_queue`** et 1 en `ep_poll` (`/proc/183806/task/*/wchan`).
  - `/health` n'utilise pas le verrou mais est synchrone : il a besoin d'un thread du pool saturé.
- Impact : en production, `render.yaml:8` lance **un seul** processus `uvicorn` (offre `free`). Quarante requêtes simultanées suffisent à geler l'API pour tous les groupes, sans redémarrage automatique garanti : lectures de synchronisation, connexions, créations de groupe. **Aucune authentification n'est nécessaire** : `/auth/login` et `POST /groups` dépendent de `db`. Avec PBKDF2 sous verrou (SEC-001), chaque requête tient le verrou 0,4 à 0,8 s, donc l'interblocage peut aussi survenir naturellement en pic de charge. Le health check Render (`healthCheckPath: /health`) échouerait ; un redémarrage par Render est une hypothèse non vérifiée.
- Recommandation : supprimer le verrou applicatif hors SQLite (voir DAT-003) et, s'il reste nécessaire en SQLite, ne jamais le prendre dans une dépendance exécutée dans le pool. Par exemple, un verrou par groupe pris dans la route, ou des routes `async` avec un `asyncio.Lock`. Ajouter un test de non-régression : 50 requêtes concurrentes puis `/health` doit répondre en moins d'une seconde. Mesure complémentaire : un `/health` asynchrone (`async def`) resterait disponible pour la supervision.
- Effort : S

### PERF-002 — Verrou global : sérialisation mesurée entre groupes (complément à SEC-001 et DAT-003)
- Sévérité : Majeur / Domaine : débit backend / Statut : confirmé (mesuré)
- Preuve : constat de fond établi par `docs/audit/06-securite.md` (SEC-001 : 4 connexions erronées font attendre une lecture 2,9 s) et `docs/audit/07-donnees.md` (DAT-003). Mesures complémentaires (`scratchpad/perf/bench.py`, API locale) :

  | Mesure | Résultat |
  |---|---|
  | `GET /health`, 200 appels séquentiels | médiane 0,9 ms, p95 1,7 ms |
  | `POST /groups` (20 membres, 3 PBKDF2) | médiane 814 ms (n=5) |
  | `POST /auth/login` correct / erroné | médiane 392 ms / 426 ms (n=5) |
  | 4 `POST /groups` en parallèle, lecture d'un **autre** groupe | lecture servie en **3 342 ms** ; créations terminées à 861, 1 652, 2 445, 3 390 ms (strictement en série) |
  | 8 snapshots lourds (6 Mo) en parallèle, lecture légère d'un autre groupe | lecture servie en **740 ms** au lieu de 2,7 ms |
  | 20 snapshots légers en parallèle, 2 groupes | médiane 32 ms contre 2,4 ms en séquentiel ; débit plafonné à ~350 req/s |

- Impact : la latence d'un groupe dépend de l'activité de tous les autres. Sur Render `free`, avec un CPU plus faible [déduit], les chiffres seront supérieurs.
- Recommandation : celle de SEC-001/DAT-003 (verrous de ligne PostgreSQL, PBKDF2 hors section critique). Ensuite, envisager plusieurs workers uvicorn, aujourd'hui impossibles à cause de la mémoire de throttling locale (`attempts`, l. 285).
- Effort : M

### PERF-003 — Coût de chaque requête proportionnel à l'agrégat ; snapshot de 6 Mo téléchargé 2 fois toutes les 45 s
- Sévérité : Majeur / Domaine : backend et réseau mobile / Statut : confirmé (mesuré côté serveur) ; volumétrie client [déduit]
- Preuve :
  - `backend/app/main.py:308-309` : chaque requête authentifiée fait `with_for_update()` puis `copy.deepcopy(group.state)` (voir DAT-002). Mesures sur trois états, 10 appels chacune :

    | État du groupe | Taille du snapshot | `GET /groups/{id}` | `PUT …/members` | Requête rejetée juste après `authenticate` (`/sync` → 409) |
    |---|---|---|---|---|
    | 20 membres sans photo | 2 020 o | 2,7 ms | 2,9 ms | 2,8 ms |
    | 1 000 membres sans photo | 49 180 o | 16,9 ms | 14,1 ms | 8,4 ms |
    | 30 membres avec photo (200 Ko base64 chacune) | **6 002 670 o** | **104,7 ms** | 39,2 ms | 21,5 ms |

    La dernière colonne isole le coût fixe d'authentification et de copie, multiplié par 8 avec 6 Mo d'état. La taille de photo choisie est une hypothèse de test : l'app accepte jusqu'à 2 Mio par photo (`player_photo.dart:12`), soit 2,8 Mo en base64 (DAT-001).
  - `mobile/lib/features/shared/data/shared_service.dart:243` : `Timer.periodic(const Duration(seconds: 45), …)` appelle `synchronize()`, qui fait **deux** `GET /groups/$groupId` (l. 550 et 656) par cycle.
  - Aucun `GZipMiddleware` dans `backend/app/main.py` (seul `CORSMiddleware`, l. 280). Un snapshot de 200 membres sans photo reste compressible (JSON) ; les photos base64 de JPEG ne le sont presque pas [déduit].
- Impact (calcul) : avec le groupe photo ci-dessus, chaque appareil connecté télécharge 12 Mo par cycle, soit **~960 Mo par heure** au premier plan sur réseau mobile, et tient le verrou global ~210 ms par cycle. Le snapshot inclut aussi `documents` (toutes les séances, avec `history` pour PDT/VP) et `audit` : il grossit avec chaque séance, sans pagination ni requête conditionnelle (`ETag`, révision).
- Recommandation : retirer les photos de l'agrégat (DAT-001) ; exposer un snapshot incrémental (`?since=<revision>`) ou un `ETag`/`304` ; un seul `GET` par cycle quand l'outbox est vide ; `GZipMiddleware` ; espacer la synchro en arrière-plan et la suspendre quand l'app n'est pas visible.
- Effort : L

### PERF-004 — Premier chargement Flutter web : 11,9 Mo, premier écran à 66 s en Fast 3G
- Sévérité : Mineur (requalifié en Phase 4, était Majeur) / Domaine : livrable web / Statut : confirmé (mesuré, serveur local sans compression)
- Preuve : `scratchpad/perf/load.mjs`, contexte vierge, cache HTTP désactivé.

  | Profil | Requêtes | Octets reçus | Écran de chargement HTML (FCP) | Événement `load` | Premier écran Flutter |
  |---|---|---|---|---|---|
  | Aucun (loopback) | 21 | 11 880 857 | 84 ms | 1,35 s | **2,05 s** |
  | 4G émulée | 21 | 11 880 857 | 392 ms | 10,0 s | **11,9 s** |
  | Fast 3G émulée | 21 | 11 117 394 | 1,30 s | 56,7 s | **66,0 s** |

  Principales ressources : `canvaskit/chromium/canvaskit.wasm` 5 429 003 o, `main.dart.js` 4 723 392 o, `remix.ttf` 501 900 o, `assets/images/logo.jpg` 289 275 o, `Roboto-Regular.ttf` 171 864 o, Poppins ×4 (~635 Ko). Aucun en-tête `Content-Encoding` ni `Cache-Control` (`curl -sI -H 'Accept-Encoding: gzip, br' …/main.dart.js` → `Server: SimpleHTTP/0.6`, `Content-Length: 4723196`).
- Compression (calcul, `gzip -9` local) : `main.dart.js` 4 723 196 → 1 312 356 o (−72 %), `canvaskit.wasm` (chromium) 5 428 806 → 2 063 289 o (−62 %), `remix.ttf` 501 712 → 221 864 o, `Poppins-Regular.ttf` 160 316 → 72 150 o. Si l'hébergeur compresse JS, WASM et TTF, le premier chargement passerait à **~4,5 Mo**, soit ~25 s en Fast 3G au lieu de 66 s [déduit]. Vercel compresse en principe les réponses selon le type de contenu, mais aucune mesure n'a pu être faite (voir hypothèses).
- Impact : un utilisateur sur réseau mobile moyen attend une dizaine de secondes devant « Ouverture de votre terrain… », une minute en 3G. Les visites suivantes dépendent du service worker (PERF-005) et du cache HTTP (PERF-014).
- Recommandation : vérifier la compression effective sur Vercel (`curl -I --compressed` sur `main.dart.js` et `canvaskit.wasm`) ; envisager `--wasm`/skwasm ou le chargement différé (`deferred as`) des écrans lourds ; réduire `logo.jpg` (289 Ko pour un logo) ; garder l'écran HTML de chargement, qui apparaît vite.
- Effort : M

### PERF-005 — Le service worker de production précache 47,5 Mo
- Sévérité : Majeur / Domaine : livrable web, cache / Statut : confirmé (mesuré sans bridage)
- Preuve :
  - `scripts/package-universal-web.mjs:33-44` liste **tous** les fichiers de `mobile/build/web`, sauf les noms commençant par `.` et les `.map`. `:48` : `install` → `cache.addAll([...ALLOWED])`. Les `.symbols` ne sont pas exclus.
  - Le `sw.js` régénéré depuis le build du 14/11 (dans le scratchpad, sans toucher au dépôt) puis injecté par `page.route` donne : SW actif à 7,0 s, **52 fichiers, 47 455 662 o en Cache Storage**.
  - Ce volume comprend 6 fichiers `.symbols` (8 581 625 o, débogage uniquement), 6 binaires de rendu (`canvaskit.wasm` 7,3 Mo, `chromium/canvaskit.wasm` 5,4 Mo, `skwasm_heavy.wasm` 5,2 Mo, `webparagraph/canvaskit.wasm` 3,7 Mo, `skwasm.wasm` 3,6 Mo, `wimp.wasm` 3,6 Mo) alors que Chrome n'a chargé que `chromium/canvaskit.wasm` (PERF-004), plus `assets/NOTICES` (1,4 Mo) et `icons/icon-1024.png` (427 Ko).
  - `mobile/web/app-shell.js:169` enregistre le SW dès le démarrage (`verify()` à la fin du script) : le préchargement concurrence le premier chargement.
- Impact (calcul) : 47,5 Mo à 180 Ko/s (Fast 3G) ≈ **4 min 24 s** de téléchargement en tâche de fond, à chaque nouvelle version (le nom du cache change à chaque build, l. 45-46). Cela consomme le forfait data et l'espace de stockage. Si l'installation échoue (coupure), `addAll` échoue entièrement et le mode hors ligne n'est pas disponible [déduit].
- Recommandation : exclure `*.symbols`, `NOTICES` et les variantes de moteur inutiles ; précacher le cœur (index, bootstrap, `main.dart.js`, une variante canvaskit, polices) et mettre le reste en cache à la demande ; différer l'enregistrement du SW après le premier rendu.
- Effort : S

### PERF-006 — Photos stockées en taille d'origine, décodées en pleine résolution sur le thread UI
- Sévérité : Majeur / Domaine : mémoire et fluidité mobile / Statut : confirmé (lecture) ; coûts [déduit], non mesurés sur appareil
- Preuve :
  - `mobile/lib/features/players/presentation/new_player_bottom_sheet.dart:38` : `_picker.pickImage(source: ImageSource.gallery)` sans `maxWidth`, `maxHeight` ni `imageQuality`.
  - `mobile/lib/core/media/player_photo.dart:47-103` : `encode` accepte jusqu'à 2 Mio et 4096×4096 px. Il décode une vignette de 128 px **seulement pour valider**, puis stocke **les octets d'origine** : `return 'data:$mime;base64,${base64Encode(bytes)}'` (l. 103).
  - `mobile/lib/core/widgets/player_avatar.dart:35` : chaque `initState` d'avatar appelle `PlayerPhoto.decode(source)`, soit une regex sur une chaîne jusqu'à 2,8 Mo, `base64Decode`, puis **`await encode(bytes)` à nouveau** (`player_photo.dart:120`, décodage d'en-tête et codec). L. 83 : `Image.memory(snapshot.data!)` sans `cacheWidth`/`cacheHeight`. Pour un avatar de 40 px, le moteur décode l'image entière (jusqu'à 16 Mpx, ~64 Mo en RGBA [déduit]).
  - Ces opérations (regex, `base64Decode`, `base64Encode`) s'exécutent sur l'isolate principal.
- Impact : saccades au défilement des listes de joueurs et de classement, pics mémoire, risque de fermeture par le système sur appareil d'entrée de gamme ; le même octet alimente la base, la sauvegarde et le snapshot serveur (PERF-003).
- Recommandation : redimensionner à l'import (par exemple 256 px JPEG qualité 80 : quelques dizaines de Ko) ; ne pas revalider à chaque affichage (valider à l'écriture) ; `cacheWidth` sur `Image.memory` ; mettre en cache les octets décodés par identifiant de joueur ; `compute()` pour le décodage base64.
- Effort : M

### PERF-007 — Synchronisation toutes les 45 s : double import complet et 19 invalidations
- Sévérité : Majeur / Domaine : synchronisation mobile / Statut : confirmé (lecture) ; coût [déduit]
- Preuve :
  - `shared_service.dart:542-680` : `synchronize()` fait `GET` → `importSnapshot` → envoi de l'outbox → `GET` → `importSnapshot`, **même sans changement local ni distant**.
  - `importSnapshot` (`:715-1001`), pour **chaque** document sportif du snapshot, exécute : `SELECT` séance (l. 931), `UPDATE` séance, `DELETE` de toutes ses participations (l. 954-958), un `INSERT` par participation (l. 961-966), 1 + 3 `INSERT` dans `meta` (l. 973-985). S'y ajoute, par document, une requête sur **tous** les `outbox_` (l. 885-890, plan `SCAN meta`, DAT-004). Soit environ 20 instructions SQL par séance de 12 joueurs, ×2 imports par cycle.
  - `:1001` `onChanged?.call()` sans condition ; `mobile/lib/main.dart:86-106` invalide alors 19 providers (séances, joueurs, classements, vues `v_*`, finances). Toutes les vues observées sont recalculées (agrégation sur tous les groupes avant filtrage, DAT-012).
  - Sur Flutter web, chaque instruction transite par le SharedWorker sqflite (`sqflite_sw.js`) : une aller-retour de message par requête [déduit].
- Impact (calcul) : avec 100 séances partagées, environ 4 000 écritures SQLite et 2 recalculs de tous les classements toutes les 45 s par appareil, même au repos. Cela use la batterie et le stockage, et peut faire sauter l'interface (re-rendus, indicateurs de chargement) pendant une saisie.
- Recommandation : comparer la révision ou `updated_at` de chaque document et n'importer que les documents modifiés ; un seul `GET` quand l'outbox est vide ; `Batch` sqflite pour les insertions ; n'appeler `onChanged` que s'il y a eu un changement ; suspendre le minuteur quand l'app est en arrière-plan ou l'onglet masqué.
- Effort : M

### PERF-008 — Suite pytest de 10 min 50 dominée par le PBKDF2 : frein au TDD
- Sévérité : Mineur (requalifié en Phase 4, était Majeur) / Domaine : outillage de tests / Statut : confirmé (journal + mesure)
- Preuve :
  - `docs/audit/raw/pytest.log` : `442 passed in 650.22s (0:10:50)`, soit 1,47 s par test en moyenne.
  - `backend/app/security.py:8` et `:14` : `600_000` itérations codées en dur. Aucun `conftest.py` dans `backend/tests/`, aucune surcharge (`grep -rn "pbkdf\|600_000\|ITERATIONS" backend/tests` ne renvoie rien).
  - Mesure : un `hashlib.pbkdf2_hmac('sha256', …, 600000)` = **0,619 s** sur la machine d'audit. Une création de groupe en calcule 3 à 4 (SEC-003), une connexion 1 (mesuré : `POST /groups` 814 ms, login 392 ms, PERF-002). Aucune exécution parallèle (`pytest-xdist` absent de `backend/requirements.txt`).
  - Par comparaison, `docs/audit/raw/flutter-test.log` : `04:13 +1358: All tests passed!`, rapide pour 1 358 tests.
- Impact : `AGENTS.md` §1 impose un cycle rouge-vert-refactor sur tous les scénarios. Onze minutes par passage complet (et `CLAUDE.md` indique ~8 min) poussent à ne lancer qu'un sous-ensemble, donc à manquer des régressions.
- Recommandation : rendre le nombre d'itérations paramétrable (variable d'environnement lue au démarrage, valeur basse imposée par une fixture de test) tout en gardant 600 000 par défaut et un test qui vérifie la valeur de production. Fixtures de groupe à portée `module` quand c'est sûr. `pytest-xdist`.
- Effort : S

### PERF-009 — Police de repli téléchargée depuis `fonts.gstatic.com` au démarrage
- Sévérité : Mineur / Domaine : livrable web / Statut : confirmé (mesuré)
- Preuve : à chaque chargement mesuré, la requête externe `https://fonts.gstatic.com/s/notosanssymbols2/v24/I_uyMoGduATTei9eI8daxVHDyfisHr71-vrgfE71.woff2` est tentée (bloquée par l'audit), avec en console `Transient error (attempt 1) for Noto Sans Symbols 2 3: Flutter Web engine failed to complete HTTP request`. Le build utilise pourtant `--no-web-resources-cdn` (`scripts/build-universal-web.sh`), et `mobile/web/flutter_bootstrap.js` ne fixe pas `fontFallbackBaseUrl`.
- Impact : requête tierce non maîtrisée (performance, confidentialité, mode hors ligne : en hors ligne les glyphes concernés manquent et le moteur relance la requête). Le domaine sécurité ou conformité peut juger la fuite d'IP vers Google plus grave.
- Recommandation : identifier le caractère qui déclenche le repli (symbole dans l'onboarding [déduit]) et le remplacer par une icône Remix, ou héberger les polices de repli et renseigner `fontFallbackBaseUrl`.
- Effort : XS

### PERF-010 — Client HTTP recréé à chaque requête, corps hors délai, JSON sur le thread UI
- Sévérité : Mineur / Domaine : réseau mobile / Statut : confirmé (lecture)
- Preuve : `mobile/lib/core/data/shared_http_native.dart:13` `HttpClient()` neuf par appel, fermé en `finally` (`client.close(force: true)`) : pas de keep-alive, donc une poignée de main TLS par requête, soit 2 à 3 par cycle de synchro (PERF-007). `:19` le délai de 90 s ne couvre que `request.close()`. `:20` `utf8.decoder.bind(response).join()` n'a pas de délai. `jsonDecode` d'un snapshot de plusieurs Mo s'exécute sur l'isolate UI. Même schéma côté web (`shared_http_browser.dart:14,20-21`, `http.Client()` par appel).
- Impact : latence ajoutée par requête sur réseau mobile (RTT × 2 pour TLS) [déduit] ; une réponse qui ralentit après les en-têtes peut bloquer la synchro sans fin (`_syncing` reste vrai, plus aucune synchro) [déduit] ; gel d'interface au décodage des gros snapshots.
- Recommandation : un client partagé par `SharedService` ; `timeout` sur la lecture complète ; `compute(jsonDecode, …)` au-delà d'un seuil de taille.
- Effort : S

### PERF-011 — Listes non virtualisées et écritures SQLite unitaires en boucle
- Sévérité : Mineur / Domaine : rendu et base locale / Statut : confirmé (lecture)
- Preuve : `players_screen.dart:105` `ListView(children: …)` construit tous les joueurs actifs et archivés, chacun avec un `PlayerAvatar` (PERF-006). Idem pour `finances_screen.dart:415`, `financial_point_screen.dart:685` (une ligne de saisie par membre) et `standings_screen.dart:367,1602,1642`. À l'inverse, `sessions_screen.dart:314` et `standings_screen.dart:200,688,807,959` utilisent `ListView.builder`. `db.batch()` n'apparaît qu'une fois (`app_database.dart:653`) ; restauration (`backup_service.dart:190-230`) et import de synchro (PERF-007) insèrent ligne par ligne.
- Impact : faible avec 20 à 30 joueurs ; coût linéaire au-delà, amplifié par les avatars. Restauration lente pour une grosse sauvegarde, surtout sur le web (SharedWorker) [déduit].
- Recommandation : `ListView.builder` / `SliverList` pour les listes de membres ; `Batch` dans les boucles d'insertion.
- Effort : S

### PERF-012 — Journal des stats en direct réécrit en entier à chaque but
- Sévérité : Mineur / Domaine : saisie en direct / Statut : confirmé (lecture) ; coût [déduit]
- Preuve : `live_stats_repository.dart:240-291` : chaque `apply` relit le journal, compare des `jsonEncode` complets (l. 254-255), ajoute une entrée contenant les instantanés `before` **et** `after` de toute la séance (l. 281-287), puis `_write` met à jour la séance et **chaque** participation (l. 117-133), et `_saveJournal` réécrit tout le JSON (l. 138-146).
- Impact : taille et temps d'écriture croissent en O(buts × joueurs) par action, donc en O(n²) sur la séance. Négligeable pour une séance ordinaire (dizaines de buts), sensible en tournoi long [déduit].
- Recommandation : journaliser le delta (`action`) et ne stocker qu'un instantané périodique ; ne mettre à jour que les participations modifiées.
- Effort : S

### PERF-013 — Poppins Regular téléchargée deux fois ; `remix.ttf` peu réduite
- Sévérité : Mineur / Domaine : livrable web / Statut : confirmé (mesuré)
- Preuve : la même URL `assets/assets/google_fonts/Poppins-Regular.ttf` (160 504 o) est reçue deux fois, y compris avec le cache HTTP actif : une fois par `@font-face` de `mobile/web/pwa-shell.css:2-4` (requête de type `font`), une fois par le moteur Flutter (type `fetch`). Les modes CORS diffèrent et le serveur local n'envoie pas d'en-tête de cache [déduit]. `docs/audit/raw/flutter-build-web.log:6` : `remix.ttf` réduite de 613 136 à 501 712 o (18,2 %), contre 99,5 % pour MaterialIcons (l. 4).
- Impact : ~160 Ko inutiles et ~500 Ko de police d'icônes au premier chargement.
- Recommandation : retirer la `@font-face` du shell (ou y utiliser une police système) ; vérifier si des `IconData` Remix non constantes empêchent l'élagage.
- Effort : XS

### PERF-014 — `vercel.json` sans en-têtes de cache
- Sévérité : Mineur / Domaine : hébergement web / Statut : confirmé (lecture) ; comportement Vercel [déduit]
- Preuve : `vercel.json` ne contient que `framework`, `installCommand`, `buildCommand` et `outputDirectory` : aucun bloc `headers`. Les ressources du moteur (`canvaskit/*`), versionnées par la version de Flutter, et les polices n'ont donc pas de `Cache-Control: immutable`. `main.dart.js` n'est pas haché (nom fixe).
- Impact : pour un navigateur sans SW (premier passage, SW refusé), chaque visite revalide les ressources. Sur Vercel, le comportement par défaut est en principe une revalidation systématique, soit des requêtes conditionnelles et un RTT par ressource [déduit, non vérifié].
- Recommandation : `headers` Vercel : `Cache-Control: public, max-age=31536000, immutable` pour `canvaskit/**` et `assets/fonts/**`, `no-cache` pour `index.html`, `sw.js`, `flutter_bootstrap.js` et `main.dart.js`.
- Effort : XS

### PERF-015 — Service worker du portail : version manuelle et images lourdes précachées
- Sévérité : Mineur / Domaine : portail `/portal/` / Statut : confirmé (lecture)
- Preuve : `web/sw.js:3` `const CACHE = PREFIX + "2026-10-17-merged-1";` est maintenue à la main, et la stratégie est « cache d'abord » pour les ressources listées (l. 72-75). Si un fichier change sans incrément de version, l'ancien reste servi [déduit]. Le précache (l. 4-28) inclut `icons/logo-transparent.png` (754 440 o), `icons/icon-1024.png` (427 505 o) et `icons/logo.jpg` (289 085 o) : 1,47 Mo d'images sur 2,1 Mo pour `web/dist` (`du -sb web/dist` = 2 097 173).
- Impact : limité, le portail est gelé (`web/CLAUDE.md`, déclaré). Risque de version obsolète servie après correctif.
- Recommandation : dériver la version d'un hachage du contenu, comme `package-universal-web.mjs` ; compresser ou retirer les grandes images du précache.
- Effort : XS

### PERF-016 — L'erreur 404 au démarrage est `sw.js`, absent du build Flutter non packagé
- Sévérité : Info / Domaine : environnement de test / Statut : confirmé
- Preuve : `curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:18090/sw.js` → `404`. `mobile/web/app-shell.js:169` enregistre `new URL("sw.js", document.baseURI)`. `sw.js` n'est écrit que par `scripts/package-universal-web.mjs:52`, absent de `mobile/build/web`. `mobile/build/web/flutter_service_worker.js` est le SW neutre de Flutter, qui se désinscrit. Le message console « A bad HTTP response code (404) was received when fetching the script » correspond à cet enregistrement : aucune autre réponse en erreur n'est observée parmi les 21 requêtes.
- Impact : aucun en production, où `sw.js` est généré. En local, aucun mode hors ligne ni mise à jour testable avec le build brut. L'app-shell affiche « Vérification indisponible » dans son menu [déduit].
- Recommandation : servir `web/universal-dist` (ou une sortie de `packageUniversal` vers un dossier temporaire) pour les tests navigateur locaux ; documenter ce point dans `mobile/CLAUDE.md`.
- Effort : XS

## Hypothèses à vérifier

- **Compression Vercel** : Vercel sert-il `main.dart.js`, `*.wasm` et `*.ttf` en brotli ou gzip ? À vérifier avec `curl -sI --compressed` sur l'URL de production, ce qui était interdit dans cet audit. Le gain attendu est quantifié en PERF-004.
- **Cache-Control par défaut de Vercel** pour les fichiers statiques sans configuration (PERF-014).
- **Comportement Render** quand `/health` ne répond plus (PERF-001) : redémarrage automatique ou indisponibilité jusqu'à intervention.
- **Démarrage à froid Render `free`** : le délai de 90 s des clients HTTP (`shared_http_*.dart`) suggère des réveils longs [déduit] ; non mesuré.
- **Coût réel de la synchro et des avatars sur appareil** (PERF-006, PERF-007) : à profiler avec Flutter DevTools sur un Android d'entrée de gamme et un groupe de 100 séances et 30 photos.
- **Chargement de `sqlite3.wasm` (748 Ko) et `sqflite_sw.js` (264 Ko)** : ils n'apparaissent pas parmi les 21 requêtes du premier écran (onboarding). Ils sont probablement chargés à la première ouverture de la base, à mesurer sur un parcours complet.
- **Préchargement SW sous réseau bridé** : non mesuré, car l'émulation CDP de la page ne s'applique pas au worker. La durée de 4 min 24 s en Fast 3G est un calcul.

## Points positifs (Info)

- `/health` n'utilise ni base ni verrou : 0,9 ms médian, et 0,6 ms pendant 4 créations de groupe concurrentes, tant que le pool de threads n'est pas saturé.
- Écran de chargement HTML statique affiché vite (FCP 84 ms en local, 1,3 s en Fast 3G) avant le moteur Flutter.
- Build sans CDN (`--no-web-resources-cdn`) : moteur et polices servis depuis l'origine ; Material et Cupertino Icons élagués à plus de 99 % (`flutter-build-web.log:4-5`).
- Version du cache du SW universel dérivée d'un hachage du contenu (`package-universal-web.mjs:42-45`), purge des anciennes versions à l'activation, requêtes authentifiées jamais mises en cache.
- `ListView.builder` sur les listes principales de séances et de classements.
- Suite Flutter rapide : 1 358 tests en 4 min 13.
- Garde `_syncing` empêchant les synchronisations concurrentes (`shared_service.dart:543`).

## Renvois vers d'autres domaines

- Sécurité : PERF-001 est exploitable sans authentification via `/auth/login` ou `POST /groups` (déni de service définitif). À rapprocher de SEC-001 et SEC-003 et à réévaluer en sévérité dans `06-securite.md`.
- Données et vie privée : PERF-009 (requête vers Google Fonts) et PERF-006 (photos en taille d'origine diffusées à tout le groupe, DAT-001).
- DevOps : l'API locale partagée `127.0.0.1:18085` est bloquée depuis la mesure de PERF-001 et doit être relancée. Absence de test de charge et de CI. Les instructions de build local ne produisent pas `sw.js` (PERF-016).
- Architecture : agrégat JSON unique (DAT-002), cause commune de PERF-002, PERF-003 et PERF-007.

## Corrections de la vérification croisée (Phase 4, 14/11/2026)

Verdicts détaillés : [raw/verification-phase4.md](raw/verification-phase4.md).

- **PERF-004** : Majeur → **Mineur**. Motif : mesuré sur serveur local sans compression ; le poids restant est structurel à Flutter web.
- **PERF-008** : Majeur → **Mineur**. Motif : durée de la suite : confort développeur, pas de risque produit.
