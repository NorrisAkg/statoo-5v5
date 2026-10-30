# Diagnostic Technique Initial Statoo

Date : 30 octobre 2026  
Branche : `staging`  
Commit de référence : `0b8c16a`

---

## 1. État des Builds, Tests et Linting

| Composant | Build | Tests | % Passants | Lint / Analyse statique |
|---|---|---|---|---|
| **Mobile (Flutter)** | OK | 836 / 836 | 100% | 134 problèmes (0 erreurs, 2 warnings, 132 infos) |
| **Web (PWA Shell / Tests)** | OK (`npm run build:web`) | 61 / 61 | 100% | Propre (Prettier configuré, 0 erreur Zod/ES) |
| **Backend (FastAPI / Pytest)** | OK | 89 / 89 | 100% | Propre (2 warnings Starlette/pytest cache) |
| **TOTAL** | **OK** | **986 / 986** | **100%** | **Baseline de tests 100% verte** |

- **Audit des dépendances npm** : 0 vulnérabilité trouvée (`npm audit`).
- **Exécution complète des tests** : Aucun test en échec sur l'ensemble de la monorepo.

---

## 2. Classification de la Dette Technique

### Dette Critique (0)
*Aucun bloqueur bloquant la compilation, les tests unitaires ou le packaging.*

### Dette Haute
1. **Atomicité validation / clôture de séance**  
   - *Fichier* : `mobile/lib/features/sessions/application/sessions_provider.dart:210`  
   - *Description* : La validation des règles métier (`SessionCloseRules`) et l'écriture de clôture (`SessionsRepository.closeSession`) ne s'exécutent pas au sein d'une transaction SQLite unique. En cas de crash ou d'erreur réseau/disque concurrente, une incohérence d'état peut survenir.
2. **Gestion et recréation des Vues SQL à froid**  
   - *Fichier* : `mobile/lib/core/data/app_database.dart:180`  
   - *Description* : Les 7 vues SQL d'agrégation (`v_standings`, `v_top_scorers`, etc.) sont systématiquement détruites et recréées à l'ouverture de la base sans vérification de version du schéma, ce qui masque d'éventuelles dérives de DDL entre migrations.

### Dette Moyenne
1. **Incohérences de style et syntaxe dans le module Finance**  
   - *Fichiers* : `mobile/lib/features/finance/data/finance_repository.dart:65`, `mobile/lib/features/finance/presentation/finances_screen.dart:135`  
   - *Description* : `async_return_with_no_await`, omission des accolades sur les blocs `if`, et cascades d'invocations redondantes (8 signalements de linting).
2. **Appels dynamiques non typés dans les fixtures de test d'import PWA**  
   - *Fichier* : `mobile/test/features/shared/pwa_wire_import_test.dart:69-78`  
   - *Description* : Utilisation d'objets `dynamic` non castés sur la désérialisation de fixtures de parité mobile-web.
3. **Absence de hook d'arrière-plan pour fermer la connexion SQLite**  
   - *Fichier* : `mobile/lib/core/data/app_database.dart:45`  
   - *Description* : La connexion SQLite reste ouverte indéfiniment ; le CDC recommandait une fermeture propre ou mise en sommeil lors du cycle de vie de l'application en arrière-plan.

### Dette Basse
1. **Warnings de lint résiduels dans la suite de tests** :
   - `mobile/test/features/sessions/session_permissions_test.dart:10:8` : import inutilisé (`participation.dart`).
   - `mobile/test/features/shared/manager_validation_test.dart:48:3` : type brut `Map<dynamic, dynamic>?` devant être explicitement paramétré (`strict_raw_type`).
2. **Ordre des directives d'imports (`directives_ordering`)** :
   - ~30 fichiers contiennent des imports de paquets et relatifs mélangés.

---

## 3. Sécurité et Failles Évidentes
- **Gestion des Secrets** : Les fichiers d'environnement (`.env`, `.env.local`, `.neon`) sont correctement déclarés dans `.gitignore` et ne sont pas suivis par git.
- **Authentification & Mots de passe** : Le backend utilise un hachage cryptographique sécurisé (argon2/pbkdf2 via `backend/app/security.py`) et des digests SHA-256 avec sels pour les jetons d'accès.
- **Injections SQL** : Toutes les requêtes SQLite dans l'application mobile et dans le backend utilisent des requêtes paramétrées (`rawQuery` avec arguments `?` ou SQLAlchemy ORM paramétré).

---

## 4. Écarts entre Architecture Annoncée et Réelle
- **Supabase** : La documentation initiale (`docs/analysis.md`) mentionnait Supabase. Le code réel s'appuie désormais sur Neon PostgreSQL pour l'API centrale et SQLite local pour le mobile, avec un service de synchronisation de sauvegardes JSON.
- **StatooRepository** : Défini dans `mobile/lib/core/domain/statoo_repository.dart`, mais les fonctionnalités actuelles passent par des repositories dédiés (`PlayersRepository`, `SessionsRepository`, `FinanceRepository`). Le fichier `statoo_repository.dart` est un reliquat théorique non utilisé en production.
