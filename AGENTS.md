# AGENTS.md — Source de Vérité Unique

## 1. Consignes Persistantes Obligatoires
- **Parité Web-Mobile (16/10/2026)** : Mobile = référence fonctionnelle. Le web réutilise le code Flutter (`mobile/lib/main_web.dart`) et les mêmes règles/transitions métier. Aucune étape escamotée sur le web.
- **Tests avant le code / TDD exhaustif (15/10/2026 & 30/10/2026)** : Pour TOUTE correction ou évolution, écrire **tous les tests incluant tous les scénarios possibles (nominaux, variantes, cas limites, erreurs, concurrence, isolation multi-tenant, régressions) et leurs résultats attendus AVANT tout code applicatif**. Cycle TDD strict : rouge (échec fonctionnel attendu), vert minimal, refactor/régression. Un échec de compilation ou de fixture n'est pas une preuve RED.
- **Revue de code systématique (25/10/2026)** : Après chaque implémentation, effectuer obligatoirement une revue de code distincte (diff, métier, intégrité, erreurs, tests). Commit uniquement après validation sans bloquant.
- **Design & Cadrage (15/10/2026)** : Lire `docs/design-system.md` avant tout écran ou modif UI. Poppins, `context.colors`, thèmes clair/sombre, 320/393 dp, texte agrandi, icônes `remixicon`.

## 2. Stack Technique et Versions
- **Mobile & Flutter Web** : Flutter 3.47.5, Dart 3.13.4, Riverpod 3.4.3, GoRouter 18.0.1, Freezed 3.1.0, sqflite 2.4.4.
- **Web PWA Shell** : Node.js v22.23.2, Zod 4.6.7, esbuild 0.28.2, Playwright, Service Worker offline.
- **Backend API** : Python 3.13.5, FastAPI 0.143.0, SQLAlchemy 2.1.4, Uvicorn, PostgreSQL (Neon) / SQLite dev.

## 3. Commandes Exactes
```bash
# Mobile (Flutter)
cd mobile && flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test                        # 836 tests unitaires & widgets
dart analyze lib test               # Analyse statique rapide (~10s)

# Web (PWA / Tests d'intégration)
npm run test:web                    # 61 tests unitaires ES modules
npm run build:web                   # Build PWA & vérification package
npm run format:web                  # Formatage prettier

# Backend (FastAPI / Pytest)
& "backend/.venv/Scripts/pytest.exe" backend/tests   # 89 tests API
```

## 4. Architecture et Règle de Dépendance
Structure Feature-First inspirée de Clean Architecture :
- `mobile/lib/core/` : base de données (`app_database.dart`), router, thème, widgets partagés.
- `mobile/lib/features/<nom>/` : découpé en 4 couches étanches :
  1. `domain/` : Entités pures `freezed`, logique métier pure, 0 dépendance Flutter/Riverpod.
  2. `data/` : Repositories SQLite, transactions, sérialisation JSON.
  3. `application/` : Providers Riverpod, contrôleurs (mutations + invalidations explicites).
  4. `presentation/` : Écrans, bottom sheets, widgets spécifiques, gestion responsive.

## 5. Données et Multi-Tenant
- Tout est scopé par `team_id`. La session active réside dans `meta` (`active_session_id_<teamId>`).
- La table `participations` est l'unique source de vérité statistique (aucun cumul pré-enregistré).
- Clôture bloquante si : score absent, joueur en double, déséquilibre d'effectif > 1 (sans dérogation).

## 6. Zones Sensibles à Risque Élevé
- `mobile/lib/features/sessions/` : logique de composition, synchronisation buts/scores, clôture.
- `mobile/lib/core/data/app_database.dart` : migrations SQLite et recalcul des 7 vues SQL.
- `backend/app/main.py` : gestion des accès rôles, tokens et opérations idempotentes.
- `mobile/lib/features/finance/` : calculs de reliquat et validations comptables.

## 7. Équipe d'Agents Dédiés
- `architect` : Planification, découpage en tâches, respect des règles Clean Architecture.
- `implementer` : Implémentation du code minimal pour passer les tests au vert.
- `test-engineer` : Rédaction des scénarios TDD, critères d'acceptation, exécution des suites.
- `reviewer` : Revue de code obligatoire avant commit (qualité, régressions, AGENTS.md).
- `mobile` : Spécialiste Flutter, Riverpod, SQLite local et design system.
- `backend-api` : Spécialiste FastAPI, PostgreSQL, auth rôles et idempotence.
- `web-parity` : Spécialiste PWA, parité mobile-web, offline et service workers.
