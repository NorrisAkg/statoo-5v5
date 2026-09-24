# Règles globales du projet Statoo

## 1. Priorités
- **Design :** Les captures d'écran priment sur le CDC. S'il y a une différence (couleur, police, disposition, libellé), suivre les captures et le signaler.
- **Fonctionnel :** Le CDC prime sur les captures (règles métier, données, validations, calculs).
- **Écrans placeholders :** Déduire le design du reste de l'app si détaillé dans le CDC. Sinon garder un placeholder.
- **Conflit insoluble :** Ne pas deviner, marquer avec `// TODO(cdc):` et demander / choisir le plus simple.

## 2. Stack Technique
- Flutter stable, Dart 3, null-safety, lints stricts (`very_good_analysis` ou `flutter_lints`).
- State Management : `flutter_riverpod` (avec `riverpod_annotation` + `riverpod_generator`).
- Routing : `go_router` avec `StatefulShellRoute.indexedStack`.
- Modèles : `freezed` + `json_serializable`.
- Base de données : `sqflite`
- UI : Widgets Flutter natifs, design system unifié (fonds sombres, etc.). Police `Inter`. Icônes `remixicon` / `flutter_remix`.
- Formattage dates : `intl`, locale `fr_FR`.

## 3. Architecture
Architecture feature-first, inspirée Clean Architecture :
- `core/` : theme, router, widgets, utils
- `features/<feature>/` : domain, data, application, presentation
- Domaine pur : aucune dépendance Flutter/Riverpod. Les calculs sont des fonctions pures.
- SQLite : Une seule connexion ouverte au démarrage, agrégats calculés via Vues SQL.

## 4. Règles Métier Importantes (CDC)
- Seule la table `participations` est source de vérité.
- Barème : 3 pts (V), 1 pt (N), 0 pt (D).
- Clôture bloquante si : manque score, joueur en double, écart d'effectif > 1 (sauf si `allow_uneven_teams` = true).
- Clôture non bloquante avec avertissement si somme des buts diffère du score.
- Classement : se base sur `status = 'CLOSED'` et `is_ranked = true`.
- Archivage : `is_active = false` (pas de suppression stricte des joueurs ayant joué).
