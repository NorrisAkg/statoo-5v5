---
paths:
  - "lib/features/*/domain/**"
  - "lib/core/domain/**"
---

# Couche domaine

- Aucun import de `package:flutter/*`, `flutter_riverpod`, `riverpod_annotation`, `sqflite` : Dart pur uniquement (`freezed_annotation`, `json_annotation`, `meta` acceptés).
- Les calculs (points, % victoires, pts/match, départage, éligibilité) sont des fonctions pures, testées dans `test/features/<feature>/`.
- Barème 3 / 1 / 0 ; classement sur `CLOSED` + `is_ranked` seulement. Ne jamais stocker un cumul : il se dérive des participations.
- Entités : `@freezed sealed class X with _$X`, `fromJson` si mappé depuis une ligne SQL ou le backup. Après modification, regénérer avec build_runner.
- Les modèles lus depuis une vue SQL (`StandingEntry`, `ScorerEntry`…) exposent un `fromMap` tolérant aux `null` et aux `int`/`double` que SQLite renvoie indifféremment.
