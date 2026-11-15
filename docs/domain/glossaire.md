# Glossaire métier Statoo

Termes tels qu'ils sont employés dans le code au 14/11/2026 (`staging`, `2a9a3c7`). Ce glossaire complète [`docs/ai/GLOSSAIRE.md`](../ai/GLOSSAIRE.md) et le corrige sur les statuts de séance et sur le terme « reliquat ». Les déductions sont marquées **[déduit]**.

| Terme (UI / doc) | Identifiant dans le code | Définition | Synonymes à éviter | Référence |
|---|---|---|---|---|
| **Groupe** | `team`, `team_id` (mobile) ; `group`, `group_id` (API, format `#NNNNNNNN`) | Unité multi-tenant : joueurs, séances, finances. `short_name` ≤ 30 caractères. | « équipe » (réservé aux camps A/B/C), « club » | `mobile/lib/features/team/`, `backend/app/main.py:395-401` |
| **Groupe partagé** | `shared_group_*` (meta), `SharedService` | Groupe relié à l'API, avec comptes et synchronisation. Sinon, le groupe est purement local. | « groupe en ligne », « cloud » | `mobile/lib/features/shared/data/shared_service.dart` |
| **Joueur** | `Player`, table `players` (mobile) ; `members[]` (API) | Personne de l'effectif. Elle est archivée (`is_active = 0`) plutôt que supprimée dès qu'elle a des participations. | « membre » côté UI mobile (réservé au roster financier et à l'API) | `mobile/lib/features/players/` |
| **Séance** | `Session`, table `sessions` | Rencontre datée (`played_at`). Statuts SQLite : `DRAFT`, `CLOSED`. `CANCELLED` n'existe que dans le protocole de synchro. | « match » (une séance peut contenir un tournoi), « session » en UI | `mobile/lib/features/sessions/domain/session.dart`, `app_database.dart:320` |
| **Séance active** | `active_session_id_<teamId>` (meta) ; `active_session_id` (API) | Le DRAFT en cours de saisie. Une seule par groupe. Ce n'est pas un statut SQL. | « séance en cours » comme statut | `app_database.dart`, `backend/app/main.py:884-900` |
| **Type de séance** | `session_type` = `CLASSIC_2` / `TOURNAMENT_3` | Classique : 2 camps et un score. Tournoi : 3 camps et des victoires (`wins_*`). | « mode 3 équipes » | `session.dart` |
| **Camp / équipe A, B, C** | `team` (participations), `team_names`, `team_colors` | Côté d'une séance, avec un nom et une couleur facultatifs parmi 8 pastilles. | « groupe » | `sessions/domain/team_appearance.dart` |
| **Participation** | table `participations` | Présence d'un joueur dans une séance : camp, buts, passes, cartons. `UNIQUE(session_id, player_id)`. | « présence », « inscription » | `sessions/domain/participation.dart` |
| **Buts non attribués** | `unassigned_goals_a/b/c` | Part du score sans buteur. Attribuer un but la consomme d'abord. | « buts fantômes » | `sessions/domain/goal_score_sync.dart` |
| **Séance classée / amicale** | `is_ranked` | Seules les séances classées et closes rapportent des points. Les amicales comptent pour les buts et les passes. | « officielle » | vues `v_player_match_results`, `v_standings` |
| **Clôture** | `SessionCloseRules`, `closeSession` | Passage de DRAFT à CLOSED après 6 contrôles bloquants. | « validation de match » | `sessions/domain/session_close_rules.dart:41-105` |
| **Dérogation d'effectif** | `allow_uneven_teams` | Autorise un écart de plus d'un joueur entre camps. | — | idem, l.92 |
| **Points d'égalité** | `draw_points` | Points d'un nul partiel de tournoi (défaut 1). À distinguer du poids MVP du nul. | — | `app_database.dart` (vues) |
| **Classement / ratio** | `v_standings`, `v_standings_per_match` | Points > victoires > matchs > nom. Le ratio exige ≥ 50 % des séances classées. | — | `ranking/data/ranking_repository.dart` |
| **Joueur du mois (MVP)** | `MvpCalculator`, `mvp_weights_*` | Score mensuel pondéré, configurable par groupe. | « homme du match » | `ranking/domain/mvp_calculator.dart` |
| **Point financier** | `FinancialPoint` ; documents `finance:<occurrence>` (API) | Bilan d'une échéance : lignes par membre, dépenses, dons. | « reliquat » (absent du code) | `finance/domain/financial_point.dart`, `backend/app/finance.py` |
| **Échéance / occurrence** | `occurrence_id` (`AAAA-MM-JJ-n`) | Identifiant partagé entre une séance et son point financier. | — | `mobile/lib/core/data/occurrence_registry.dart` |
| **Cotisation / taux** | `contribution`, `rate`, `financial_settings.contribution` | Montant dû par membre et par échéance. | « frais » | idem |
| **Pénalité** | `penalty_due`, `penalty_paid`, `late_penalty` | Dette et paiement de pénalité. `late_penalty` est stocké mais inutilisé dans les calculs côté serveur. | « amende » | `backend/app/main.py:163,514,774` |
| **Obligation** | `obligations{}` (API) | Échéance à zéro créée côté serveur à la première acceptation d'une séance. | — | `backend/app/main.py:816-820` |
| **Solde d'ouverture / revue d'ouverture** | `opening`, `opening_proposal` | Soldes initiaux proposés par TR/TGA, puis approuvés à l'identique par PDT/VP. | « bilan initial » | `backend/app/main.py:720-750` |
| **Solde / avance / dette** | `financial_report.dart` | Position financière d'un membre. C'est le vocabulaire réel, à la place de « reliquat ». | **« reliquat »** (employé dans `AGENTS.md` mais absent du code) | `mobile/lib/features/finance/domain/financial_report.dart:19-36` |
| **Accès collectif** | compte `shared: true` | Identifiant partagé par le groupe, en lecture seule. | « compte membre » | `backend/app/main.py:321-323` |
| **Compte individuel / gestionnaire** | `accounts[]`, `shared: false` | Compte nominatif qui porte au moins un rôle de responsable. | « manager » en UI FR | `add_manager_bottom_sheet.dart` |
| **Rôles** | `ADMIN`, `PDT`, `VP`, `TR`, `TGA`, `SG`, `SGA`, `CENSOR`, `MEMBER` | `PDT` = président, `TR` = trésorier, `VP` = vice-président. `TGA`, `SG`, `SGA`, `CENSOR` = trésorier adjoint, secrétaire général, adjoint, censeur **[déduit]**. Tous sauf `ADMIN` et `MEMBER` sont uniques. | — | `backend/app/main.py:30-33` |
| **Co-administrateur** | plusieurs comptes `ADMIN` | ADMIN n'est pas un rôle unique (ACCESS-02). | — | `backend/tests/test_co_admins.py` |
| **Code de récupération** | `recovery`, `/auth/recover` | Code à usage unique de fait (rotation obligatoire), réservé à un ADMIN. | « mot de passe de secours » | `backend/app/main.py:443-504`, `mobile/lib/features/shared/domain/recovery_code.dart` |
| **Révision / génération / propriétaire** | `revision`, `generation`, `owner` | Versionnement optimiste d'un document partagé. | — | `backend/app/main.py:752-825` |
| **Candidature / conflit / arbitrage** | `candidates`, `/resolve` | Version concurrente en attente d'arbitrage par PDT/VP. | — | idem, l.827 |
| **Outbox** | `outbox_<opId>` (meta) | File locale des opérations à synchroniser : `pending`, `accepted`, `conflict`, `rejected`, `blocked`. | « file d'attente » côté portail (`pending`) | `docs/outbox-sync.md` |
| **Portail** | `web/`, `/portal/` | Ancienne PWA JS, conservée pour les préparations historiques. | « PWA » sans précision (la PWA principale est Flutter web) | `web/README.md:3` |
