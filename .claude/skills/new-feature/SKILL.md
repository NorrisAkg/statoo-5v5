---
name: new-feature
description: Crée ou étend une feature Statoo (écran, provider, repository, entité) en respectant l'architecture feature-first, le scoping par team_id et les conventions du dépôt. À utiliser pour ajouter un écran, une fonctionnalité CDC ou un nouveau flux.
---

# Nouvelle feature Statoo

## 1. Cadrer

- Retrouver la section du CDC (`docs/Statoo_Cahier_des_Charges_v1.1.pdf`) et la capture (`statoo-captures/`) concernées. Fonctionnel = CDC, design = capture. Ambiguïté bloquante : `// TODO(cdc):` + option la plus simple, et le dire.
- Regarder la feature la plus proche (`sessions` pour un flux complet, `ranking` pour de la lecture de vues) et copier sa forme.

## 2. Construire de bas en haut

1. **domain/** : entité `@freezed` (+ `fromJson`/`fromMap`), calculs en fonctions pures. Aucun import Flutter/Riverpod.
2. **data/** : `abstract class XRepository` + `SqliteXRepository(AppDatabase)`, requêtes filtrées par `teamId`. Schéma modifié → skill `db-migration`.
3. **application/** : `Provider<XRepository>`, puis `FutureProvider`/`AsyncNotifier` qui lisent `activeTeamIdProvider` et renvoient `null`/`[]` sans groupe actif. Les écritures passent par un contrôleur qui lève `StateError` sans groupe et invalide **tous** les providers dérivés (voir `SessionsController._invalidateAll`).
4. **presentation/** : `ConsumerWidget`/`ConsumerStatefulWidget`, `context.colors`, widgets de `core/widgets/`, icônes `Remix.*`, dates `fr_FR`. Route déclarée dans `core/router/app_router.dart` (onglet = branche du shell ; écran poussé = `parentNavigatorKey: _rootNavigatorKey`).
5. `dart run build_runner build --delete-conflicting-outputs` si des annotations ont changé.

## 3. Tester

- Unitaire pour chaque règle du domaine ; widget test de l'écran avec providers surchargés (modèle : `test/features/sessions/new_session_screen_test.dart`).
- `dart analyze` sur les fichiers touchés (zéro info nouvelle), `flutter test`.

## 4. Relire

- Agent `design-fidelity` si l'écran a une capture, puis agent `statoo-reviewer`. Corriger les FAIL avant de proposer le commit (`smart-commit`).
