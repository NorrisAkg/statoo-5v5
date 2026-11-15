# Questions ouvertes — onboarding du 14/11/2026

Points non établis avec certitude, ou qui relèvent d'une décision du propriétaire. Ce registre complète [`docs/decisions-and-risks.md`](../decisions-and-risks.md), daté du 12/10. Plusieurs des risques qui y figurent ont été traités depuis (fermeture SQLite, atomicité de la clôture) : ils sont à requalifier.

## Produit

1. **Portail historique `web/`.** Faut-il le retirer, ou le maintenir à parité ? Il ne propose ni récupération, ni changement de mot de passe, ni co-admins, mais il est toujours servi sur Vercel et sur l'API.
2. **Fonctions sans client.** Les endpoints ACCESS-03 (`POST /groups/{id}/account/password`) et de régénération du code de récupération (`PUT …/account/recovery-code`) n'ont d'appelant ni dans le mobile ni dans le portail. Est-ce un travail en cours, ou un oubli ?
3. **Minimum de joueurs d'un groupe partagé.** Il ne se modifie que depuis le portail (`PUT …/sport-settings`). Le mobile le reçoit en lecture seule. Est-ce voulu ?
4. **Score par défaut d'une séance classique.** Elle démarre à 0-0, résultat nul (`TODO(cdc)` dans `sessions_provider.dart:223`), ce qui permet de la clôturer sans aucune saisie. Ce comportement est-il validé ?
5. **Principe des quatre yeux.** Un compte qui cumule TGA et VP peut proposer **et** approuver les soldes d'ouverture. Un co-admin peut réinitialiser le mot de passe d'un autre admin. Est-ce acceptable ?
6. **`late_penalty`.** Il est paramétrable mais n'entre dans aucun calcul serveur. La règle reste à préciser.
7. **Signification exacte des rôles** `TGA`, `SG`, `SGA` et `CENSOR`. Elle est déduite, aucun libellé ne l'établit dans le backend.

## Technique

8. **Tests mobiles.** Les 16 échecs ont été diagnostiqués et corrigés le 14/11 sur `fix/mobile-red-tests`. Deux points restent ouverts :
   - le chiffre de 836 tests (`AGENTS.md`, `docs/ai/DIAGNOSTIC.md`) correspond-il à un autre périmètre ?
   - Le code mort du sélecteur de carton a été supprimé, et la garde « séance déjà active » est couverte côté écran (`new_session_active_draft_guard_test.dart`), sur la même branche.
   - Reste ouvert : la garde côté contrôleur (`sessions_provider.dart:263-271`) et le cas d'un `activeDraftSessionProvider` encore en chargement au moment de valider (l'écran envoie alors `startImmediately = true`) n'ont aucun test dédié.
9. ~~**Version Python de référence.**~~ Tranché le 15/11/2026 (DEP-001/OPS-005) : 3.12.3, fixé dans `render.yaml` (`PYTHON_VERSION`) et vérifié par `backend/tests/test_dependency_lock.py`. Reste à décider quand monter de version (correctif 3.12 plus récent, puis 3.13).
10. ~~**Plan Render.**~~ Tranché le 15/11/2026 (OPS-006) : plan gratuit conservé, risque accepté (veille, démarrage à froid, pas de disponibilité garantie), une seule instance. Reste à décider quand passer sur une offre payante (au plus tard avant des groupes réels) et à mettre en place une sonde externe (OPS-003).
10 bis. **Production.** `STATOO_PUBLIC_API_URL` est-elle définie sur Vercel ? Quelle origine Vercel figure dans `CORS_ORIGINS` sur Render ? Ces deux réglages ne sont pas visibles dans le dépôt.
11. **Proxy Render.** Uvicorn est-il lancé avec `--proxy-headers` ou `forwarded-allow-ips` ? Le throttling par IP en dépend. `render.yaml` ne le montre pas.
12. **Moment du commit.** Avec les dépendances `yield` de FastAPI 0.143, le commit SQL a-t-il lieu avant l'envoi de la réponse ? Point à vérifier.
13. **Branches.** `origin/main` (pile Nuxt/Capacitor, août) doit-il être remplacé par `staging` ? Les branches locales `feat/*` déjà fusionnées peuvent-elles être supprimées ?
14. **Distribution mobile.** Signature Android, publication iOS et versions déjà installées (anciennes bases à migrer) restent non documentées. Le point était déjà ouvert dans `decisions-and-risks.md`.
15. **Schéma SQLite.** `sessions.team_id` est nullable sur une base neuve, mais `NOT NULL` sur une base migrée depuis une version antérieure à v7. Ce point est à arbitrer dans la prochaine migration.

## Documentation

16. **Doublons.** `docs/ai/` (ARCHITECTURE, GLOSSAIRE, DIAGNOSTIC) et `docs/architecture.md`, `business-rules.md`, `conventions.md` (12/10) recouvrent les nouveaux documents. Lesquels faut-il garder comme référence ? Faut-il marquer les autres comme historiques ?
17. **`AGENTS.md` et `GEMINI.md`** divergent. Faut-il garder une source unique ?
18. **Journaux de tests.** Environ 400 fichiers `.txt` (sorties RED/GREEN) encombrent `docs/`. Faut-il les archiver dans `docs/archives/` ou les retirer du suivi ?
