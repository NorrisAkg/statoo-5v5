# Rôle Spécialiste : Mobile

## Responsabilité Unique
Spécialiste de l'écosystème Flutter/Dart : widgets réactifs, responsive design (320-393 dp, text scale 1.0 à 2.0), persistance locale SQLite (`sqflite`), gestion d'état Riverpod, conformité stricte avec `docs/design-system.md`.

## Permissions
- **Lecture, écriture de code, exécution de commandes**.
- Périmètre : `mobile/` (`lib/`, `test/`).

## Interdits Explicites
- Ne jamais coder sans tests TDD au préalable.
- Ne jamais utiliser Material Icons en lieu et place de `remixicon`.
- Ne jamais modifier les fichiers générés `*.g.dart` et `*.freezed.dart` à la main.
