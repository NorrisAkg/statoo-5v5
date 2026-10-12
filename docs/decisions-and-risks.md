# Décisions, risques et questions ouvertes

Registre du 12 octobre 2026, branche refonte, référence 40f13fc. **Confirmé** : visible dans le code. **À vérifier** : risque non reproduit. **À confirmer** : arbitrage du propriétaire. L'autorisation de documenter ne ratifie pas les choix produit.

## Décisions produit à confirmer

| Sujet | Code confirmé | Arbitrage | Sources |
|---|---|---|---|
| Plateformes | Android et iOS présents | Les deux à livrer ? | android/, ios/, CDC §1/3 |
| Groupes | Plusieurs groupes | Extension officielle du mono-groupe ? | lib/features/team/data/team_repository.dart |
| Tournoi | Trois camps et victoires | Maintenir ce mode exclu initialement ? | lib/features/sessions/domain/session.dart, CDC §2 |
| MVP | Score mensuel configurable | Formule/éligibilité officielles ? | lib/features/ranking/domain/mvp_calculator.dart |
| Clôture | Écart buts/score bloquant | Remplace l'avertissement du CDC ? | lib/features/sessions/domain/session_close_rules.dart, CDC §5 |
| Score | Initialisation classique 0-0/DRAW | Clôture sans première saisie explicite admise ? | lib/features/sessions/application/sessions_provider.dart |
| Backup | Manuel local, fusion/remplacement | Abandon du cloud/automatisme ratifié ? | lib/features/settings/data/backup_service.dart, CDC §6.4 |
| Architecture | Feature-first, migrations Dart, MVP partiellement Dart | Dérogations SQL initiales admises ? | lib/core/data/app_database.dart, CDC §3 |
| Design | Poppins, clair/sombre | Actualiser références Inter ? | lib/core/theme/app_theme.dart, CLAUDE.md |

## Risques actuels

| Priorité | Qualification | Risque | Source |
|---|---|---|---|
| Haute | À vérifier | Ancien schéma c359dd3 sans teams, consultée par migration actuelle | lib/core/data/app_database.dart, historique Git |
| Haute | À vérifier | Reconstruction parent sessions v7 et PRAGMA dans onUpgrade : conservation des participations | lib/core/data/app_database.dart |
| Haute | Confirmé par lecture | Tournoi CLOSED sans scores classiques rétrogradé en DRAFT à l'import | lib/features/settings/data/backup_service.dart |
| Haute | Confirmé par lecture | Versions futures non explicitement refusées ; meta.schema_version à 1 pour DB v7 | lib/features/settings/domain/backup_payload.dart, lib/core/data/app_database.dart |
| Moyenne | Confirmé par lecture | Fusion multi-groupes vers un seul ; targetTeamId absent dans appel UI | lib/features/settings/data/backup_service.dart, lib/features/settings/presentation/settings_screen.dart |
| Moyenne | À vérifier | Stats/historique joueur en cache après mutation séance, invalidations explicites absentes | lib/features/sessions/application/sessions_provider.dart |
| Moyenne | Confirmé par lecture | Avatar local passé à NetworkImage ; images absentes du backup | lib/features/players/presentation/new_player_bottom_sheet.dart, lib/features/sessions/presentation/new_session_screen.dart |
| Moyenne | Confirmé par lecture | SharedPreferences hors atomicité SQL ; export sans snapshot unique | lib/features/settings/data/backup_service.dart |
| Moyenne | Confirmé par lecture | Release Android avec repli sur signature debug | android/app/build.gradle.kts |
| Moyenne | À vérifier | Portrait et accès galerie iOS | ios/Runner/Info.plist, lib/main.dart |

Le registre n'est pas un audit exhaustif et ne prétend pas reproduire les risques « à vérifier ».

## Historique utile

- 037049c : validation backup, multi-groupes et remappage.
- 1a3af10 : tournoi intégré à refonte.
- e4999d7 : écart buts/score devenu bloquant.
- 0a84f7a : accès par identifiant scopés au groupe et triggers.
- 7366221 : archivés exclus du ratio.
- 68dd8b3 : correction double comptage score/buteur.
- aaca479 : Poppins embarquée.
- 40f13fc : signature Android dédiée.

L'historique Nuxt/Capacitor explique l'origine, pas le runtime courant. Les audits de septembre précèdent plusieurs corrections : ne pas reprendre leurs verdicts comme état actuel.

Sources : historique Git ; `docs/audit_reports/audit-2026-09-25.md`, `docs/audit_reports/audit-2026-09-30.md`.

## Informations requises et suite

À obtenir du propriétaire : plateformes/canaux livrés ; versions installées et anciennes bases/backups à préserver ; arbitrages ci-dessus ; politique des archivés/ex aequo ; SDK Flutter de référence et gestion des signatures.

Après arbitrage : consigner décisions datées, actualiser les instructions d'agents obsolètes et compléter le guide de release avec les résultats réellement exécutés. Les audits et références historiques sont conservés pour traçabilité.
