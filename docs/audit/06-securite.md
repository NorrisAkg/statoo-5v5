# Audit Statoo — 06. Sécurité

- **Domaine** : sécurité applicative (authentification, autorisation, validation, injections, XSS, CORS, en-têtes, portail statique, throttling, stockage client, sauvegarde, secrets, journaux, erreurs).
- **Date** : 14/11/2026. Arbre de travail de `fix/mobile-red-tests` (HEAD `2a9a3c7`).
- **Méthode** : lecture statique du code (`backend/app/*.py`, `mobile/lib/features/shared/`, `mobile/lib/core/data/`, `mobile/lib/features/settings/data/backup_service.dart`, `web/*.mjs`, `web/sw.js`, `render.yaml`, `vercel.json`, `.gitignore`) et **sondes exécutées en local** avec `create_app("sqlite:///:memory:")` via `TestClient` (scripts dans le scratchpad de la session, aucun appel réseau, aucune écriture hors mémoire). Sorties `npm-audit.log` et `pip-audit.log` reprises de `docs/audit/raw/`.
- **Limites** : configuration réelle de Render, Vercel et Neon invisible (proxy, variables, en-têtes ajoutés par l'hébergeur). Aucun test de pénétration sur la production. Les temps mesurés (PBKDF2 ≈ 0,7 à 0,9 s par vérification) viennent de la machine locale ; l'offre Render `free` est probablement plus lente [déduit]. `pytest.log` était incomplet au moment de la rédaction (suite en cours).

## Synthèse

Les fondations cryptographiques sont saines : PBKDF2-SHA256 à 600 000 itérations avec sel aléatoire et comparaison à temps constant, jetons de 256 bits stockés en SHA-256, révocation des jetons au changement ou à la réinitialisation de mot de passe, à la récupération et à la rotation de l'accès collectif. Les 17 routes `/groups/{group_id}/…` passent toutes par `scoped()` : aucune fuite entre groupes ni IDOR trouvée. Aucun SQL brut côté backend, SQL paramétré côté mobile, aucun `innerHTML` alimenté par des données dans le portail.

Les faiblesses portent sur la **disponibilité et la résistance aux abus**. Un verrou global entoure chaque requête et contient le calcul PBKDF2 : quelques connexions erronées bloquent toute l'API (mesuré : 2,9 s d'attente pour une lecture derrière 4 connexions ratées). `POST /groups` n'a ni rate limit ni limite de taille. Le throttling par IP ne voit probablement que l'IP du proxy Render. Trois endpoints servent d'oracle de mot de passe sans throttling. Côté autorisation, un co-admin, ou un jeton admin volé, peut prendre le contrôle du groupe : il réinitialise le mot de passe de l'autre admin sans ressaisir le sien, le rétrograde, et son code de secours est alors supprimé. Un même compte peut cumuler TR et PDT et approuver ses propres soldes d'ouverture.

**Note proposée : 3/5.** Pas de faille critique d'isolation ni d'injection. En revanche, un attaquant non authentifié peut dégrader le service à faible coût, et les contrôles d'administration manquent de garde-fous (pas de ré-authentification, pas de séparation des tâches).

## Tableau récapitulatif

| ID | Sévérité | Titre | Fichier principal | Effort |
|---|---|---|---|---|
| SEC-001 | Critique (requalifié, était Majeur) | Verrou global + PBKDF2 sous verrou : déni de service non authentifié | `backend/app/main.py:284` | M |
| SEC-002 | Majeur | Throttling par IP inopérant derrière le proxy Render, en mémoire et non borné | `backend/app/main.py:423` | S |
| SEC-003 | Majeur | `POST /groups` sans rate limit ni limite de corps | `backend/app/main.py:349` | S |
| SEC-004 | Mineur (requalifié, était Majeur) | Prise de contrôle par un co-admin ou un jeton admin volé (sans ré-authentification) | `backend/app/main.py:577` | M |
| SEC-005 | Majeur | Oracles de mot de passe sans throttling (verify gestionnaire, verify commun, recovery-code) | `backend/app/main.py:568` | S |
| SEC-006 | Mineur (requalifié, était Majeur) | Un seul compte peut cumuler TR et PDT et approuver ses propres soldes d'ouverture | `backend/app/main.py:632` | S |
| SEC-007 | Mineur | Aucune limite de taille de corps, dictionnaires libres et chaînes non bornées | `backend/app/main.py:102` | S |
| SEC-008 | Mineur | Mots de passe des gestionnaires et du compte commun conservés en clair sur l'appareil de l'admin | `mobile/lib/features/shared/data/collective_access.dart:104` | M |
| SEC-009 | Mineur | Énumération des groupes et identifiants par mesure du temps de `/auth/login` | `backend/app/main.py:430` | XS |
| SEC-010 | Mineur | Jetons de 30 jours sans rotation, sans purge, sans déconnexion globale | `backend/app/main.py:329` | S |
| SEC-011 | Mineur | Aucun en-tête de sécurité HTTP (API, portail, Vercel) | `vercel.json:1` | S |
| SEC-012 | Mineur | `/docs` et `/openapi.json` exposés en production | `backend/app/main.py:263` | XS |
| SEC-013 | Mineur | Le compte commun voit les identifiants des responsables et le journal d'audit | `backend/app/main.py:509` | XS |
| SEC-014 | Mineur | `STATOO_API` vise la production par défaut | `mobile/lib/features/shared/presentation/shared_group_screen.dart:56` | XS |
| SEC-015 | Mineur | Sauvegarde mobile non chiffrée, restauration réinjectant l'outbox | `mobile/lib/features/settings/data/backup_service.dart:76` | M |
| SEC-016 | Mineur | Build Android release signé silencieusement avec la clé debug | `mobile/android/app/build.gradle.kts:55` | XS |
| SEC-017 | Mineur | `.gitignore` commité ne couvrait pas `.env.*` ; fichiers locaux suivis | `.gitignore:10` | XS |
| SEC-018 | Mineur | Le serveur accepte un code de secours choisi par le client, même trivial | `backend/app/main.py:35` | XS |
| SEC-019 | Info | Format de hachage sans version d'algorithme ni d'itérations | `backend/app/security.py:9` | S |
| SEC-020 | Info | Mot de passe gestionnaire généré sur 8 caractères (≈ 45 bits) | `mobile/lib/features/shared/data/manager_password.dart:10` | XS |

Répartition : 0 Critique, 6 Majeur, 12 Mineur, 2 Info.

## Matrice d'autorisation vérifiée (routes de `00-cadrage.md` §5.2)

| Ligne | Route | Appartenance (`scoped`) | Contrôle de rôle | Remarque |
|---|---|---|---|---|
| 349 | `POST /groups` | — (public) | — | SEC-003 |
| 421 | `POST /auth/login` | — | — | SEC-002, SEC-009 |
| 437 | `POST /auth/logout` | jeton | — | supprime le jeton courant |
| 443 | `POST /auth/recover` | — | ADMIN non commun avec code | throttling IP 10/min + compte 5/15 min |
| 506 | `GET /groups/{g}` | oui | filtrage par rôle | SEC-013 |
| 537 | `POST …/accounts` | oui | ADMIN non commun | |
| 568 | `POST …/accounts/{a}/password/verify` | oui (`individual_access`) | ADMIN | SEC-005 |
| 577 | `POST …/accounts/{a}/password` | oui | ADMIN, cible ≠ soi | SEC-004 |
| 590 | `POST …/account/password` | oui | compte individuel | throttling 5/min par compte |
| 612 | `PUT …/account/recovery-code` | oui | ADMIN non commun | SEC-005 |
| 632 | `PUT …/accounts/{a}/roles` | oui | ADMIN | SEC-004, SEC-006 |
| 658 | `PUT …/members` | oui | ADMIN | SEC-007 |
| 675 | `POST …/shared-access/verify` | oui | ADMIN | SEC-005 |
| 686 | `PUT …/shared-access` | oui | ADMIN | révoque les jetons du compte commun |
| 702 | `PUT …/financial-settings` | oui | ADMIN, TR, TGA | |
| 711 | `PUT …/sport-settings` | oui | ADMIN | |
| 720 | `POST …/opening` | oui | TR, TGA | |
| 738 | `POST …/opening/approve` | oui | PDT, VP | SEC-006 |
| 752 | `POST …/sync` | oui | `AUTHORS[domain]` | `team_id` du payload = groupe (l. 911) |
| 827 | `POST …/documents/{d}/{o}/resolve` | oui | PDT, VP | `domain` non validé, sans effet de sécurité (clé absente → 409) |
| 860 | `POST …/documents/{d}/{o}/transfer` | oui | propriétaire ou PDT/VP ; cible auteur du domaine | |

`account_id`, `occurrence_id` et `domain` sont toujours recherchés dans `state` du groupe authentifié : aucun accès inter-groupe possible. `require()` (l. 321-323) refuse systématiquement le compte commun.

## Constats

### SEC-001 — Verrou global + PBKDF2 sous verrou : déni de service non authentifié
- Sévérité : Critique (requalifié en Phase 4, était Majeur) / Domaine : disponibilité, authentification / Statut : confirmé (mesuré en local)
- Preuve :
  - `backend/app/main.py:284` `lock = threading.Lock()` et `main.py:298-300` : `def db(): with lock, Session(engine) as session, session.begin(): yield session`. Toute route qui dépend de `db` ou `authenticate` s'exécute sous ce verrou, y compris sur PostgreSQL, malgré le commentaire de la l. 282.
  - `login` (l. 421-435), `recover` (l. 443-504), `register` (l. 349-419) et les routes `verify` appellent `password_matches`/`password_hash` (600 000 itérations, `security.py:8,14`) **à l'intérieur** de la session, donc sous le verrou.
  - Mesure locale (`TestClient`, SQLite mémoire) : une connexion erronée prend 0,874 s. Avec 4 connexions erronées lancées en parallèle, un `GET /groups/{g}` légitime a attendu **2,867 s** ; les 4 connexions ont fini à 0,74, 1,59, 2,35 et 3,16 s, donc strictement l'une après l'autre.
- Impact : environ un appel `/auth/login` erroné par seconde, sans authentification, suffit à geler toute l'API pour tous les groupes. Le throttling de 20 tentatives/min par IP ne protège pas : il suffit de quelques IP, ou d'une seule si SEC-002 se confirme. `POST /groups` (SEC-003) calcule 3 à 4 hachages sous verrou par appel et n'a aucun throttling.
- Recommandation : supprimer le verrou applicatif sur PostgreSQL et s'appuyer sur `with_for_update()`, déjà utilisé l. 308 et 471. Sortir les calculs PBKDF2 de la section critique : lire le hash, relâcher, vérifier. À défaut, un verrou par `group_id`. Ajouter un test de non-régression qui vérifie qu'une lecture n'est pas bloquée par une connexion en cours.
- Effort : M

### SEC-002 — Throttling par IP inopérant derrière le proxy Render, en mémoire et non borné
- Sévérité : Majeur / Domaine : authentification / Statut : [déduit] pour Render, confirmé pour le code
- Preuve :
  - `backend/app/main.py:423` `key = request.client.host` ; même schéma l. 445 pour `/auth/recover`.
  - `render.yaml:8` `startCommand: uvicorn app.main:app --host 0.0.0.0 --port $PORT` : ni `--proxy-headers` explicite, ni `--forwarded-allow-ips`.
  - Uvicorn 0.54.0 du venv : `proxy_headers=True`, mais `forwarded_allow_ips` vaut par défaut `FORWARDED_ALLOW_IPS` ou `"127.0.0.1,::1"` (`uvicorn/config.py:363`). `X-Forwarded-For` n'est donc pris en compte que si le proxy Render se connecte depuis la boucle locale, ce qui est improbable [déduit].
  - Les compteurs `attempts`, `recover_ip_attempts` et `recover_account_attempts` (l. 285-288) sont des `dict` en mémoire de processus. Leurs clés viennent de l'attaquant (l. 446 `f"{group_id}:{username}"`) et ne sont jamais purgées.
  - Aucun test backend n'exerce le 429 de `/auth/login` (`grep -l "429\|Trop de tentatives" backend/tests/*.py` ne renvoie que `test_change_password.py` et `test_recovery_code.py`).
- Impact : si tous les clients partagent l'IP du proxy, 20 connexions erronées par minute bloquent **toutes** les connexions légitimes et 10 récupérations erronées bloquent toutes les récupérations. Si, au contraire, `FORWARDED_ALLOW_IPS=*` est configuré dans Render (non visible), `X-Forwarded-For` devient falsifiable et le throttling est contournable. Les dictionnaires grossissent sans limite, puis sont remis à zéro à chaque redémarrage ou mise en veille du service.
- Recommandation : fixer `--proxy-headers --forwarded-allow-ips` avec la plage documentée par Render, ou lire l'en-tête de l'hébergeur de façon explicite. Ajouter un throttling par compte (`group_id` + identifiant) sur `/auth/login`. Borner et purger les compteurs, ou les persister en base. Tester le 429 de `/auth/login`.
- Effort : S

### SEC-003 — `POST /groups` sans rate limit ni limite de corps
- Sévérité : Majeur / Domaine : abus, disponibilité / Statut : confirmé (exécuté)
- Preuve : `backend/app/main.py:349-419` n'appelle ni `throttle` ni de contrôle d'IP. Sonde locale : 25 créations consécutives depuis le même client renvoient toutes `201`. `Registration.members: list[dict]` (l. 102) accepte jusqu'à 1 000 dictionnaires de contenu libre. Chaque appel calcule 3 à 4 PBKDF2 (l. 386, 394, 390, 411).
- Impact : création massive de groupes (pollution de Neon, quota de l'offre gratuite), saturation CPU combinée à SEC-001, et chaque appel renvoie un jeton valide 30 jours.
- Recommandation : throttling par IP corrigée (SEC-002) et quota global ; limite de taille du corps ; schéma Pydantic strict pour `members`.
- Effort : S

### SEC-004 — Prise de contrôle par un co-admin ou un jeton admin volé (sans ré-authentification)
- Sévérité : Mineur (requalifié en Phase 4, était Majeur) / Domaine : autorisation / Statut : confirmé
- Preuve :
  - `backend/app/main.py:577-588` `reset_manager_password` : un ADMIN remplace le mot de passe de **n'importe quel** compte individuel, y compris un autre ADMIN. Seule sa propre cible est refusée (l. 580). Aucune ressaisie du mot de passe de l'acteur (comparer avec `change_own_password` l. 596 ou `regenerate_recovery_code` l. 617).
  - `main.py:632-656` `roles` : un ADMIN peut retirer `ADMIN` à un autre admin tant qu'un admin subsiste (l. 651-653). Le code de secours de la cible est alors supprimé (l. 648-649).
  - Comportement voulu et testé : `backend/tests/test_co_admins.py:105` `test_admin_can_reset_another_admin_password`, `:166` `test_co_admin_can_be_demoted_if_another_admin_exists`, `:193` `test_demoted_admin_loses_recovery_code`.
- Impact : un co-admin malveillant, ou quiconque détient un jeton admin valide 30 jours (appareil perdu, stockage web, voir SEC-008), peut verrouiller le créateur hors du groupe. Il réinitialise son mot de passe, ce qui révoque ses jetons (l. 584-585), puis le rétrograde, ce qui efface son code de secours : le créateur n'a plus aucun recours. Le journal d'audit est modifiable par le même acteur via ses écritures, et reste la seule trace.
- Recommandation : exiger le mot de passe courant de l'acteur (step-up) pour la réinitialisation d'un autre compte et pour tout changement de rôle ADMIN. Envisager l'interdiction de rétrograder le créateur, ou un délai et une notification. Trancher la question ouverte n° 5 (`docs/onboarding/questions-ouvertes.md:11`).
- Effort : M

### SEC-005 — Oracles de mot de passe sans throttling
- Sévérité : Majeur / Domaine : authentification / Statut : confirmé (exécuté)
- Preuve :
  - `backend/app/main.py:568-575` `POST …/accounts/{a}/password/verify` renvoie 400 ou `verified` pour le mot de passe d'un autre compte, sans throttling. Sonde : 12 essais consécutifs → 12 × `400`, aucun `429`.
  - `main.py:675-684` `POST …/shared-access/verify` : même schéma.
  - `main.py:612-618` `PUT …/account/recovery-code` vérifie `current_password` sans throttling, contrairement à `change_own_password` (l. 595). Sonde : 8 essais → 8 × `400`.
- Impact : un détenteur de jeton admin peut tester sans limite les mots de passe des autres gestionnaires, utiles en cas de réutilisation hors Statoo, ou le mot de passe de son propre compte (avec un jeton volé, cela donne le mot de passe permanent). Chaque essai coûte un PBKDF2 sous le verrou global (SEC-001).
- Recommandation : appliquer `throttle()` par acteur et par cible sur les trois routes. Réévaluer le besoin d'un endpoint qui vérifie le mot de passe d'un tiers : le client ne l'utilise que pour mémoriser ce mot de passe (`collective_access.dart:75-79`).
- Effort : S

### SEC-006 — Un seul compte peut cumuler TR et PDT et approuver ses propres soldes d'ouverture
- Sévérité : Mineur (requalifié en Phase 4, était Majeur) / Domaine : autorisation, intégrité financière / Statut : confirmé (exécuté) ; arbitrage métier requis
- Preuve : `backend/app/main.py:632-656` autorise un ADMIN à se donner `PDT` et `TR` (`check_roles` l. 335-338 n'interdit pas le cumul). Sonde locale : `PUT …/accounts/{moi}/roles {"roles":["ADMIN","PDT","TR"]}` → 200 ; `POST …/opening` → 200 ; `POST …/opening/approve` par le même jeton → 200 `{"ok":true}`. La documentation admet le cumul (`docs/shared-group-and-finance.md:9` « Les titulaires peuvent cumuler des rôles »), mais la séparation proposition/approbation (TR/TGA proposent, PDT/VP approuvent, l. 723 et 741) perd alors son objet.
- Impact : les soldes d'ouverture, base de tous les calculs de reliquat, peuvent être fixés et validés par une seule personne. Même cas pour la résolution des conflits financiers par un PDT qui est aussi TR.
- Recommandation : refuser dans `approve_opening` l'approbation par l'auteur de la proposition (stocker `proposed_by`), ou interdire le cumul TR/TGA avec PDT/VP. Décision à prendre (question ouverte n° 5).
- Effort : S

### SEC-007 — Aucune limite de taille de corps, dictionnaires libres et chaînes non bornées
- Sévérité : Mineur / Domaine : validation d'entrée / Statut : confirmé (exécuté)
- Preuve : sonde locale `PUT …/members` avec un membre contenant un champ de 5 Mo → `200`. Champs libres ou non bornés : `Registration.members: list[dict]` (l. 102), `PUT /members` `body: list[dict]` (l. 659), `VersionInput.payload: dict` (l. 145, seules les clés sport vérifiées sont contrôlées par `validate_sport`, les clés supplémentaires sont conservées l. 802-807), `VersionInput.operation_id: str` (l. 140), `AccountInput.member_id` (l. 122), `Decision.candidate_id` (l. 151), `Transfer.account_id` (l. 156). Les `candidates` d'un document (l. 789-793) et `audit` croissent sans borne. Aucune limite de corps dans `render.yaml:8` ni dans l'app.
- Impact : un compte authentifié (ADMIN pour `members`, auteur pour `/sync`) peut gonfler l'agrégat JSON du groupe, recopié en entier à chaque requête (`copy.deepcopy` l. 309) et renvoyé à tous les clients. Cela dégrade le service pour tout le groupe et, via SEC-001, pour toute l'API.
- Recommandation : middleware de limite de corps (par exemple 256 Kio, 1 Mio pour `/sync`), schémas Pydantic stricts (`extra="forbid"`) pour membres et payload sport, `max_length` sur tous les identifiants, plafond du nombre de candidats par document.
- Effort : S

### SEC-008 — Mots de passe des gestionnaires et du compte commun conservés en clair sur l'appareil de l'admin
- Sévérité : Mineur / Domaine : stockage client / Statut : confirmé ; protection sur Flutter web [déduit]
- Preuve : `mobile/lib/features/shared/data/collective_access.dart:104` `await service.storage.write(key: key, value: password);` pour le mot de passe commun et, avec `managerAccountId`, pour celui de chaque gestionnaire (`_key` l. 36-43, `regenerate` l. 18-27). `copyText` (l. 116-125) assemble identifiant et mot de passe pour le presse-papiers (`collective_access_section.dart:217`). Le stockage est `FlutterSecureStorage` (`shared_service.dart:15`), qui s'appuie sur Keystore/Keychain en natif. Sur Flutter web, le paquet repose sur `localStorage` avec une clé de chiffrement elle-même stockée côté navigateur [déduit, non vérifié dans le paquet]. Le jeton de session y est aussi stocké (`shared_service.dart:147`).
- Impact : la compromission de l'appareil ou du navigateur de l'admin expose les identifiants de tous les gestionnaires, pas seulement les siens. Le presse-papiers est lisible par d'autres applications.
- Recommandation : ne conserver que ce qui est indispensable (le mot de passe commun, s'il doit être partagé) ; faire changer le mot de passe généré au premier usage du gestionnaire plutôt que le mémoriser ; effacer le presse-papiers après un délai. Documenter le niveau de protection réel sur Flutter web.
- Effort : M

### SEC-009 — Énumération des groupes et identifiants par mesure du temps de `/auth/login`
- Sévérité : Mineur / Domaine : authentification / Statut : confirmé (exécuté)
- Preuve : `backend/app/main.py:429-433` ne calcule le PBKDF2 que si le groupe et le compte existent. Sonde : groupe inconnu 0,005 s ; identifiant inconnu 0,005 s ; identifiant existant avec un mauvais mot de passe 0,711 s. `/auth/recover` utilise au contraire un hash factice (l. 473, 485).
- Impact : un attaquant distingue les `group_id` existants (8 chiffres, l. 401) et les identifiants valides avant de lancer une attaque par mots de passe.
- Recommandation : appeler `password_matches(body.password, DUMMY_RECOVERY_HASH)` ou un hash factice dédié dans les deux branches d'échec.
- Effort : XS

### SEC-010 — Jetons de 30 jours sans rotation, sans purge, sans déconnexion globale
- Sévérité : Mineur / Domaine : gestion de session / Statut : confirmé
- Preuve : `backend/app/main.py:330-332` jeton `secrets.token_urlsafe(32)` à expiration fixe de 30 jours, sans renouvellement. `logout` (l. 437-441) ne supprime que le jeton courant. Aucun code ne supprime les jetons expirés : `authenticate` les refuse (l. 306) mais ils restent en base. Aucune route « déconnecter tous mes appareils » : seuls `change_own_password` (l. 605-607), `reset_manager_password`, `recover` et `rotate_shared` révoquent en masse.
- Impact : un jeton volé reste utilisable 30 jours ; la table `tokens` croît indéfiniment.
- Recommandation : durée plus courte avec renouvellement glissant, purge périodique des jetons expirés (au login par exemple), route de révocation globale.
- Effort : S

### SEC-011 — Aucun en-tête de sécurité HTTP
- Sévérité : Mineur / Domaine : en-têtes / Statut : confirmé
- Preuve : sonde `GET /health` → en-têtes `content-length`, `content-type`, `vary` uniquement. `vercel.json:1-6` ne déclare aucune clé `headers`. `grep -riE "content-security-policy|x-frame|strict-transport"` dans `mobile/web`, `web/index.html`, `scripts/`, `backend/app` → aucun résultat.
- Impact : pas de HSTS, pas de CSP, pas de `X-Content-Type-Options`, pas de protection anti-clickjacking pour Flutter web (Vercel) ni pour `/portal/` (servi par FastAPI). Ce qu'ajoutent éventuellement Vercel ou Render n'est pas vérifiable depuis le dépôt.
- Recommandation : bloc `headers` dans `vercel.json` (HSTS, `X-Content-Type-Options: nosniff`, `frame-ancestors 'none'`, CSP compatible avec Flutter/CanvasKit et SQLite WASM) ; middleware équivalent dans FastAPI.
- Effort : S

### SEC-012 — `/docs` et `/openapi.json` exposés en production
- Sévérité : Mineur / Domaine : exposition / Statut : confirmé (exécuté en local)
- Preuve : `backend/app/main.py:263` `FastAPI(title="Statoo", version="0.1.0", lifespan=lifespan)` sans `docs_url=None`/`openapi_url=None`. Sonde : `/openapi.json` → 200, `/docs` → 200.
- Impact : la cartographie complète de l'API, avec ses schémas, est publique, ce qui facilite les abus SEC-003, SEC-005 et SEC-007.
- Recommandation : désactiver la documentation lorsque `RENDER` est défini.
- Effort : XS

### SEC-013 — Le compte commun voit les identifiants des responsables et le journal d'audit
- Sévérité : Mineur / Domaine : exposition de données / Statut : confirmé (exécuté)
- Preuve : `backend/app/main.py:509` inclut `audit` et `main.py:517` `result["leaders"] = [public_account(a) … if not a["shared"]]` pour **tout** compte, y compris le compte commun. Sonde : connecté avec le compte commun, `leaders` contient `['admin1']` et `audit` 3 entrées (acteur, action, motif).
- Impact : tout membre détenteur de l'accès collectif connaît l'identifiant de connexion de chaque responsable, ce qui donne la moitié des informations nécessaires à une attaque ciblée (SEC-002, SEC-009), ainsi que les motifs saisis dans l'audit.
- Recommandation : n'exposer aux comptes non responsables que le libellé du rôle et le `member_id`, sans `username` ; filtrer `audit`.
- Effort : XS

### SEC-014 — `STATOO_API` vise la production par défaut
- Sévérité : Mineur / Domaine : configuration / Statut : confirmé
- Preuve : `mobile/lib/features/shared/presentation/shared_group_screen.dart:56-59` et `recovery_request_sheet.dart:109-112` `defaultValue: 'https://statoo-api.onrender.com'` ; `scripts/build-universal-web.sh:17` même valeur par défaut.
- Impact : un `flutter run` de développement sans `--dart-define` crée de vrais groupes et comptes en production ; c'est le même risque que celui que les règles git du projet cherchent à éviter.
- Recommandation : pas de valeur par défaut (échec explicite) en dehors des builds release, ou défaut local `http://127.0.0.1:8000`.
- Effort : XS

### SEC-015 — Sauvegarde mobile non chiffrée, restauration réinjectant l'outbox
- Sévérité : Mineur / Domaine : sauvegarde / Statut : confirmé pour l'export ; [déduit] pour le rejeu
- Preuve : `mobile/lib/features/settings/data/backup_service.dart:76-83` exporte **toute** la table `meta`, dont `shared_snapshot_<groupe>` (membres, documents, finances, `leaders`, `audit`) et les événements `outbox_*`, en JSON clair. Le jeton et les mots de passe n'y figurent pas : ils sont dans le stockage sécurisé. En restauration par écrasement, `backup_service.dart:181` vide `meta` puis `:218-220` réinsère toutes les entrées du fichier, y compris `outbox_*`. Seule la fusion refuse les clés `finance_`, `shared_`, `outbox_` (l. 147).
- Impact : le fichier partagé, par messagerie par exemple, divulgue les données financières et nominatives du groupe partagé. Un fichier de sauvegarde forgé, restauré par un responsable connecté, ferait rejouer des événements `outbox_*` vers `/sync` avec son jeton [déduit]. Le serveur revérifie les droits, mais l'action serait attribuée à la victime.
- Recommandation : exclure `outbox_*` et `shared_snapshot_*` de l'export, ou les ignorer à la restauration ; proposer un chiffrement par phrase de passe. Renvoyer la vérification du rejeu au domaine sauvegarde.
- Effort : M

### SEC-016 — Build Android release signé silencieusement avec la clé debug
- Sévérité : Mineur / Domaine : chaîne de livraison / Statut : confirmé
- Preuve : `mobile/android/app/build.gradle.kts:55` `signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")`.
- Impact : un APK « release » construit sans `key.properties` est signé avec la clé debug publique, sans échec ni avertissement, et peut être distribué par erreur.
- Recommandation : faire échouer `assembleRelease` sans configuration de signature, ou afficher un avertissement bloquant hors CI.
- Effort : XS

### SEC-017 — `.gitignore` commité ne couvrait pas `.env.*` ; fichiers locaux suivis
- Sévérité : Mineur / Domaine : secrets / Statut : confirmé
- Preuve : `git diff HEAD -- .gitignore` montre que `.env.*`, `!.env.example`, `CLAUDE.local.md` et `.claude/settings.local.json` ne sont ajoutés que dans l'arbre de travail, **non commités**. Le `.gitignore` de `HEAD` ne couvrait que `.env`, `.env.local` et `.env.*.local` : un `.env.production` aurait pu être commité. Aucun fichier `.env*` autre que `.env.example` n'apparaît dans l'historique (`git log --all --diff-filter=A --name-only`). Fichiers suivis sans secret mais propres au poste : `android/local.properties` (clés `sdk.dir`, `flutter.sdk`, …) et `ios/Flutter/flutter_export_environment.sh`. `mobile/android/.gitignore` couvre bien `key.properties` et `**/*.jks`.
- Impact : risque de commit accidentel d'un fichier d'environnement, chemins locaux publiés.
- Recommandation : commiter la mise à jour du `.gitignore` ; retirer du suivi `android/local.properties` et `ios/Flutter/flutter_export_environment.sh` (artefacts déjà signalés dans `CLAUDE.md`).
- Effort : XS

### SEC-018 — Le serveur accepte un code de secours choisi par le client, même trivial
- Sévérité : Mineur / Domaine : authentification / Statut : confirmé
- Preuve : `backend/app/main.py:35` `RECOVERY_CODE_RE = ^[A-Z0-9]{16,64}$` est le seul contrôle (`normalize_recovery_code` l. 39-43), appliqué à l'inscription (l. 104-109), à `recover` (l. 460-461) et à `regenerate_recovery_code` (l. 619). Le client mobile génère 16 caractères aléatoires sûrs (`mobile/lib/features/shared/domain/recovery_code.dart:10-21`, `Random.secure()`, environ 79 bits), mais un appel direct peut enregistrer `AAAAAAAAAAAAAAAA`.
- Impact : faible tant que seul le client officiel est utilisé ; un code faible serait deviné malgré le throttling par compte (5 essais toutes les 15 min).
- Recommandation : générer le code côté serveur, ou rejeter les codes à faible entropie (caractère répété, alphabet hors Crockford).
- Effort : XS

### SEC-019 — Format de hachage sans version d'algorithme ni d'itérations
- Sévérité : Info / Domaine : cryptographie / Statut : confirmé
- Preuve : `backend/app/security.py:9` `return salt + ":" + digest` ; l'itération `600_000` est codée en dur l. 8 et 14. `password_matches` lève `ValueError` sur un format inattendu (l. 13).
- Impact : impossible d'augmenter le coût ou de migrer vers Argon2/scrypt sans casser les hash existants.
- Recommandation : préfixer `pbkdf2_sha256$600000$sel$digest` et re-hacher au login quand les paramètres changent.
- Effort : S

### SEC-020 — Mot de passe gestionnaire généré sur 8 caractères (≈ 45 bits)
- Sévérité : Info / Domaine : politique de mot de passe / Statut : confirmé
- Preuve : `mobile/lib/features/shared/data/manager_password.dart:10-15` : 3 caractères imposés + 5 tirés dans un alphabet de 54 symboles, `Random.secure()`. La politique serveur (`backend/app/main.py:198-210`) impose 8 à 200 caractères, minuscule, majuscule et chiffre, sans liste de mots de passe compromis.
- Impact : suffisant contre une attaque en ligne bien throttlée, mais à la limite basse pour des comptes TR/PDT si SEC-002 et SEC-005 ne sont pas corrigés.
- Recommandation : 12 caractères ou plus pour les mots de passe générés.
- Effort : XS

## Hypothèses à vérifier

1. **IP vue par l'API sur Render** : journaliser `request.client.host` et `X-Forwarded-For` sur staging pour confirmer SEC-002, et vérifier si `FORWARDED_ALLOW_IPS` est défini dans le tableau de bord Render.
2. **JSON très profond** : un corps imbriqué à grande profondeur pourrait provoquer un `RecursionError` à l'analyse, et donc une erreur 500, avant validation Pydantic. Non testé.
3. **Erreurs 500** : `next(...)` sans valeur par défaut (`main.py:366`, `:681`, `:690`) lève `StopIteration` si l'état est incohérent. FastAPI renvoie alors une 500 générique sans trace : aucune fuite d'information observée, à confirmer en production.
4. **Rejeu de l'outbox restaurée** (SEC-015) : à démontrer par un test d'intégration mobile.
5. **Protection réelle de `flutter_secure_storage` sur web** (SEC-008) : vérifier l'implémentation de la version verrouillée dans `mobile/pubspec.lock`.
6. **Origines CORS de staging** (`main.py:277-279`) : si le service staging partage la base de production, les origines locales autorisées élargissent la surface d'attaque. Configuration Neon/Render non visible.
7. **Sauvegarde Android** : `android:allowBackup` n'est pas déclaré (`mobile/android/app/src/main/AndroidManifest.xml:3-6`), la valeur par défaut est donc `true`. La base SQLite pourrait partir dans la sauvegarde cloud Google [déduit].

## Points positifs (Info)

- PBKDF2-SHA256 à 600 000 itérations, sel aléatoire de 16 octets, `hmac.compare_digest` (`backend/app/security.py:6-15`).
- Jetons `secrets.token_urlsafe(32)`, stockés uniquement en SHA-256 (`main.py:330-332`, `models.py:17-22`).
- Révocation des jetons au changement de mot de passe (hors jeton courant), à la réinitialisation par un admin, à la récupération et à la rotation du compte commun (`main.py:584`, `605`, `497`, `696`).
- Isolation multi-tenant : les 17 routes de groupe appellent `scoped()` ; `team_id` du payload sport vérifié (`main.py:911`).
- Récupération ACCESS-01 : hash factice pour un temps constant, throttling par IP et par compte, code à usage unique avec rotation obligatoire, refus du compte commun et des non-admins (`main.py:443-504`).
- Messages d'erreur génériques : `RequestValidationError` → message fixe (`main.py:265-267`), « Identifiants incorrects » sans distinction.
- `/portal/config.json` en liste blanche (`main.py:268-271`) ; `PortalFiles` en liste blanche avec contrôle des liens symboliques (`backend/app/portal.py:20-30`), couvert par `test_portal_exposure.py`.
- CORS sans `allow_credentials`, méthodes et en-têtes restreints (`main.py:280-281`) ; authentification par en-tête `Bearer`, donc pas de surface CSRF.
- Aucun SQL brut côté backend (ORM SQLAlchemy uniquement). Côté mobile, toutes les requêtes `meta` sont paramétrées ; les seules interpolations (`app_database.dart:244, 247, 286`) portent sur des constantes ou des noms lus dans `sqlite_master`.
- Portail : les 3 `innerHTML` (`web/app.mjs:206, 579, 606`) n'injectent que du SVG ou HTML statique ; le reste passe par `textContent`. Jeton en `sessionStorage` (`web/client.mjs:105, 227`). `web/sw.js` ne met en cache que la liste blanche et ignore les requêtes avec `Authorization`.
- Mobile : HTTPS imposé à la connexion, sauf pour l'hôte local (`shared_service.dart:119-125`) ; aucun `badCertificateCallback`, aucun `print` ou `debugPrint` dans `lib/`.
- Dépendances : `npm audit` → « found 0 vulnerabilities » ; `pip-audit` → « No known vulnerabilities found » (`docs/audit/raw/npm-audit.log`, `pip-audit.log`).
- Keystore Android et `key.properties` ignorés (`mobile/android/.gitignore`) ; aucun secret dans l'historique git.

## Renvois vers d'autres domaines

- Concurrence et taille de l'agrégat JSON (`copy.deepcopy`, verrou global), au-delà de l'angle sécurité : domaine performance/backend.
- Bug `resolve` qui ignore `obligations` (`main.py:848` ne passe pas par `financial_points`) : domaine finance/métier.
- `password_matches` et `StopIteration` qui produisent des 500 : domaine robustesse/erreurs.
- Absence de CI pour exécuter les tests de sécurité existants : domaine outillage.
- Contenu complet de la sauvegarde et rejeu de l'outbox : domaine données/sauvegarde.

## Corrections de la vérification croisée (Phase 4, 14/11/2026)

Verdicts détaillés : [raw/verification-phase4.md](raw/verification-phase4.md).

- **SEC-001** : Majeur → **Critique**. Motif : exploitable sans authentification ; même défaut qu'un interblocage reproduit (PERF-001), y compris avec 60 POST /auth/login sur groupe inexistant.
- **SEC-004** : Majeur → **Mineur**. Motif : comportement voulu (ACCESS-02) et couvert par test_co_admins.py ; décision produit ouverte (questions-ouvertes n° 5).
- **SEC-006** : Majeur → **Mineur**. Motif : reproduit, mais le cumul de rôles est admis par la doc ; décision produit ouverte (questions-ouvertes n° 5).
