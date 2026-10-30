# Diagnostic Technique & Bilan Qualité Statoo

Date : 30 octobre 2026  
Branche de référence : `staging` & `feat/API-01-starlette-httpx`  

---

## 1. État des Builds, Tests et Linting

| Composant | Build | Tests | % Passants | Lint / Analyse statique |
|---|---|---|---|---|
| **Mobile (Flutter)** | OK | 836 / 836 | 100% | Propre (0 erreur, 0 warning sur commits récents) |
| **Web (PWA Shell / Tests)** | OK (`npm run build:web`) | 61 / 61 | 100% | Propre (Prettier configuré, 0 erreur Zod/ES) |
| **Backend (FastAPI / Pytest)** | OK | 406 / 406 | 100% | Propre (0 erreur, 0 warning) |
| **TOTAL** | **OK** | **1 303 / 1 303** | **100%** | **Baseline de tests 100% verte sans avertissement** |

- **Audit des dépendances npm** : 0 vulnérabilité trouvée (`npm audit`).
- **Audit des dépendances Python** : aucune dépendance brisée (`pip check`).
- **Exécution complète des tests** : Aucun test en échec sur l'ensemble de la monorepo.

---

## 2. Bilan de la Dette Technique

### Dette Critique (0)
*Aucun bloqueur bloquant la compilation, les tests unitaires ou le packaging.*

### Dette Haute (0)
*Toutes les dettes hautes ont été résolues :*
1. **Atomicité validation / clôture de séance** : Résolu dans le Sprint 1 (`SPORT-01`).
2. **Gestion et auto-guérison des Vues SQL à froid** : Résolu dans le Sprint 2 (`DATA-01`).

### Dette Moyenne (0)
*Toutes les dettes moyennes ont été résolues :*
1. **Incohérences de style et syntaxe dans le module Finance** : Résolu dans le Sprint 1 (`TECH-01`).
2. **Typage strict des fixtures de test d'import PWA** : Résolu dans le Sprint 2 (`PARITY-01`).
3. **Gestion du cycle de vie de connexion SQLite en arrière-plan** : Résolu dans le Sprint 2 (`PERF-01`).

### Dette Basse (0)
1. **Warnings de lint résiduels dans la suite de tests** : Corrigés dans le Sprint 1 (`TECH-01`).
2. **Warning de dépréciation Starlette testclient** : Éliminé dans le Sprint 3 (`API-01`).
3. **Documentation des flux outbox et cycle SQLite** : Rédigée dans le Sprint 3 (`DOC-01`).

---

## 3. Sécurité et Failles Évidentes
- **Gestion des Secrets** : Les fichiers d'environnement (`.env`, `.env.local`, `.neon`) sont correctement déclarés dans `.gitignore` et ne sont pas suivis par git. Seul `.env.example` est présent.
- **Authentification & Mots de passe** : Le backend utilise un hachage cryptographique sécurisé (argon2/pbkdf2 via `backend/app/security.py`) et des digests SHA-256 avec sels pour les jetons d'accès.
- **Injections SQL** : Toutes les requêtes SQLite dans l'application mobile et dans le backend utilisent des requêtes paramétrées (`rawQuery` avec arguments `?` ou SQLAlchemy ORM paramétré).
