# Glossaire Métier Statoo

Vocabulaire métier extrait du code source (`mobile/lib/`, `backend/app/`, `web/`).

| Terme | Définition technique / métier | Source code |
|---|---|---|
| **Groupe (Team)** | Entité racine multi-tenant (`team_id`). Regroupe joueurs, séances, finances et classements. Possède un nom, un `short_name` (<=30 car.), et des identifiants collectifs / managers. | `mobile/lib/features/team/`, `backend/app/models.py` |
| **Séance (Session)** | Événement sportif de football à 5. Statuts : `DRAFT` (brouillon / en cours), `CLOSED` (clôturée), `CANCELLED` (annulée). Type : classique (Camp A vs B) ou tournoi (Camp A, B, C). | `mobile/lib/features/sessions/domain/session.dart` |
| **Séance Active** | Brouillon en cours de match pour un groupe, référencé dans la table `meta` par la clé composite `active_session_id_<teamId>`. Une seule séance active par groupe. | `mobile/lib/core/data/app_database.dart` |
| **Camp (TeamAppearance)** | Camp sportif dans une séance (A, B, ou C). Possède un nom personnalisé (défaut : "Équipe A/B/C") et une couleur parmi 8 pastilles. | `mobile/lib/features/sessions/domain/team_appearance.dart` |
| **Participation** | Ligne liant un joueur à une séance avec son camp, ses buts, passes décisives, cartons jaunes/rouges. **Seule source de vérité** pour les statistiques. | `mobile/lib/features/sessions/domain/participation.dart` |
| **Match Classé (`is_ranked`)** | Séance fermée comptabilisée dans le classement du championnat (barème 3 pts victoire, 1 pt nul, 0 pt défaite). Un match amical (`is_ranked = false`) compte pour les stats de buts/passes mais pas pour les points de classement. | `mobile/lib/features/ranking/` |
| **Règles de Clôture** | Conditions bloquantes à la fermeture d'une séance : score renseigné, aucun joueur en double, écart d'effectif <= 1 (sauf `allow_uneven_teams = true`), cohérence buts joueurs / score d'équipe, et pas d'auto-passes impossibles. | `mobile/lib/features/sessions/domain/session_close_rules.dart` |
| **MVP (Most Valuable Player)** | Joueur du mois calculé selon un barème pondéré (victoire +10, nul +3, but +2, passe +1, carton jaune -0.5, carton rouge -1), avec seuil de participation minimale. | `mobile/lib/features/ranking/domain/mvp_calculator.dart` |
| **Accès Collectif** | Identifiant et mot de passe partagés permettant à tous les membres du groupe de consulter en lecture seule les résultats, séances et finances sans compte nominatif. | `backend/app/main.py`, `mobile/lib/features/shared/` |
| **Accès Manager** | Identifiants avec rôles spécifiques : `ADMIN`, `PDT` (Président), `VP` (Vice-Président), `TR` (Trésorier), `TGA` (Trésorier Adjoint), `SG` (Secrétaire Général), `SGA` (Secrétaire Général Adjoint), `CENSOR` (Censeur), `MEMBER` (Membre). | `backend/app/main.py`, `web/portal/` |
| **Point Financier** | Enregistrement de trésorerie du groupe : solde initial, cotisations, dépenses du terrain, reliquat, avec contrôle de cohérence et validation Trésorier/Trésorier Adjoint. | `mobile/lib/features/finance/`, `backend/app/finance.py` |
| **Parité Mobile-Web** | Principe fondamental selon lequel le web (PWA Flutter et shell) et le mobile partagent les mêmes étapes, règles, validations et flux hors-ligne. | `docs/parite-web-mobile.md`, `AGENTS.md` |
