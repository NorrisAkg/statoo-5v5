# Prompt de reprise — corrections post-audit Statoo (état au 15/11/2026)

> À donner tel quel à un nouvel agent. Il remplace l'historique de la session précédente.

---

Tu reprends les corrections issues de l'audit du dépôt Statoo (`/home/norris/my-projects/statoo-5v5`, monorepo : Flutter `mobile/`, API FastAPI `backend/`, portail JS gelé `web/`, scripts `scripts/`). L'audit est terminé ; ses livrables sont dans `docs/audit/`. Le **lot 1** du plan d'action est entièrement traité. Ta mission : poursuivre avec le **lot 2**, constat par constat, après accord de l'utilisateur sur chaque constat.

## 1. À lire avant toute action

1. `CLAUDE.md` et `AGENTS.md` à la racine (ils priment), puis le `CLAUDE.md` du dossier concerné (`mobile/`, `backend/`, `web/`).
2. `docs/audit/plan-d-action.md` : lots 1 à 4, et la table **« Suivi des corrections »** en fin de fichier, qui détaille chaque correction faite, ses tests, ses revues et ce qui reste.
3. `docs/audit/index.csv` : un constat par ligne ; la dernière colonne porte l'état (`CORRIGÉ …`, `RISQUE ACCEPTÉ …`, `confirmé Phase 4`).
4. Le rapport du domaine du constat traité (`docs/audit/01-metier.md` à `11-dependances.md`).
5. Pour toute UI : `docs/design-system.md`, en particulier les arbitrages du 26/10 et du 15/11.

## 2. Règles impératives

- **Aucune commande git d'écriture** : ni commit, add, push, pull, fetch, checkout, stash, reset, rebase, merge, ni création de branche. L'utilisateur fait ses commits lui-même. Lecture libre (`status`, `log`, `diff`, `show`, `branch`, `remote`).
- **TDD strict** (`AGENTS.md` §1) : tous les scénarios écrits avant le code ; un RED doit être un échec **fonctionnel** (une erreur de compilation ou de fixture ne compte pas). Vérifie qu'un test est discriminant, par exemple en retirant temporairement le correctif ; restaure ensuite le fichier.
- **Revue distincte** après chaque implémentation, par un sous-agent (`statoo-reviewer` ou général) à qui tu donnes le code et le périmètre, pas ta conclusion. Corrige tout bloquant **et** tout important, puis fais relire à nouveau, jusqu'à un PASS. Les revues précédentes ont trouvé de vrais défauts à chaque tour : ne saute pas cette étape.
- **Ne jamais lire** de fichier `.env*`, de clé, de certificat ni de `CLAUDE.local.md` ; noter seulement le nom d'une variable.
- **Rien en production** : ne pas lancer `scripts/neon_smoke.py`, `scripts/check-online-api.py`, ni les e2e reliés à l'API publique (`live-integration`, `group-entry`, `collective-access`, `manager-access`). Aucun déploiement, aucune écriture dans Neon. Sans `--dart-define=STATOO_API`, Flutter vise la production.
- Les règles sport, finance et rôles existent en **trois copies** (`mobile/lib/features/sessions/domain/`, `backend/app/main.py`, `web/domain.mjs`) : les aligner et passer les tests de parité.
- Tout en **français** : UI, messages d'erreur, documentation, rapports.
- Une décision de produit, de coût ou de sécurité revient à l'utilisateur : pose la question avec des options et une recommandation.

## 3. Commandes et pièges de l'environnement

```bash
# Flutter (hors du PATH bash)
export PATH=$HOME/development/flutter/bin:$PATH
cd mobile && flutter test            # 1482/1482 au 15/11 (≈ 2 min 30)
cd mobile && dart analyze lib test   # référence : 0 erreur, 71 infos ; n'en ajoute aucune

# Backend (lancer en arrière-plan : ≈ 10 min)
cd backend && .venv/bin/pytest -q -p no:cacheprovider    # 503 passés au 15/11

# Web
npm run test:web                     # 72/72
```

Pièges déjà rencontrés :
- `dart format` sur un fichier existant non formaté le reformate en entier et pollue le diff. Formate seulement les fichiers neufs ; sinon, contrôle avec `git diff --stat`.
- Dans un test, `finder.first` évalué sur un finder **vide** lève « Bad state: No element » (piège dans `scrollUntilVisible`). `scrollUntilVisible` exige aussi un finder qui ne désigne qu'un seul élément.
- `tester.getSemantics(find.byType(TextField))` ne renvoie pas le nœud de saisie : lis plutôt le descendant `EditableText`. Le texte d'exemple (`hintText`) reste dans l'arbre, invisible, après la saisie.
- Les listes paresseuses ne construisent pas les éléments hors écran : fais défiler avant de vérifier.
- Le `.venv` backend date d'avant le lockfile (FastAPI 0.143.2, opentelemetry-api 1.45.1). Il faut le recréer (DEP-003) avec `python3.12 -m venv .venv && .venv/bin/pip install --require-hashes -r requirements-dev.lock`, mais seulement avec l'accord de l'utilisateur.
- Un `Monitor` fondé sur `pgrep -f motif` se détecte lui-même : ne t'en sers pas.

## 4. Ce qui a été fait (lot 1, tout est **non commité**)

Le détail complet se trouve dans la table « Suivi des corrections » de `plan-d-action.md`.

| ID | Résumé | Reste |
|---|---|---|
| PERF-001 (+SEC-001, ARC-002, DAT-003, PERF-002) | Plus de verrou global sur PostgreSQL ; verrou `asyncio` sur SQLite ; tests de concurrence avec un vrai uvicorn. | Pool SQLAlchemy (5+10) inférieur aux 40 threads AnyIO : dégradation au-delà d'environ 15 requêtes simultanées. Non testable sans PostgreSQL. |
| SEC-002 + OPS-007, SEC-005 | IP client configurable (`STATOO_TRUSTED_PROXY_HOPS` ou `STATOO_CLIENT_IP_HEADER`) ; limites de connexion et de vérification de mot de passe. | **Définir la variable sur Render avant le prochain déploiement** (sinon l'API refuse de démarrer). Vérifier la position de l'IP réelle dans X-Forwarded-For. Tests de `forgive` (rejeu après `IntegrityError`, 503) non écrits. |
| SEC-003 | **Partiel** : 5 créations de groupe par heure et par IP. | Limite de taille de corps, différée avec DAT-001 (photos base64). |
| UX-001 | « Annuler » d'un carton cible ce carton (entrée compensatoire). | L'entrée compensatoire s'affiche comme une action dans « Dernières actions ». |
| UX-003 | Identifiant de groupe avec ou sans `#` ; message de refus explicite. | Préremplir le dernier groupe connu. |
| MET-002 | Minimum de joueurs appliqué côté mobile (création, démarrage, retrait, clôture). | Transaction de `closeSession` sans le minimum ; « Bad state: » affiché dans `new_session_screen.dart:220` ; l'écran contrôle encore avec `state` ; aucun test ne prouve qu'une création refusée n'écrit pas `shared_occurrence_*`. |
| DEP-001 + OPS-005, DEP-002 | `requirements.lock` / `requirements-dev.lock` avec empreintes (uv, multiplateforme) ; Python 3.12.3 fixé sur Render ; opentelemetry-api 1.45.2. | Recréer le `.venv` (DEP-003) ; passer au dernier correctif 3.12 ; vérifier les journaux du build Render. |
| PERF-005 | Précache du service worker : 47,5 Mo → 21,1 Mo. | Différer l'enregistrement du SW ; une seule variante CanvasKit ; police Noto Sans Symbols 2 absente hors ligne. |
| A11Y-001, -003, -004 (+A11Y-002 partiel) | Anneau de focus commun (`core/widgets/focus_ring.dart`) ; tooltips ; `LabeledField` (`core/widgets/labeled_field.dart`) ; feuille d'ajout tardif en mode compact (grand texte, clavier ou largeur < 360 dp), focus conservé par `GlobalKey`. Scanner `test/accessibility/accessible_names_source_test.dart`. 7 revues, PASS final. | Bouton « Valider l'entrée » en fin de défilement en mode compact ; anneau au-dessus d'un FAB ; lecteurs d'écran réels non testés ; reste d'A11Y-002. |
| OPS-006 | **Risque accepté** par l'utilisateur : plan gratuit Render, `numInstances: 1`, `--workers 1`, garde-fous dans `test_dependency_lock.py`. | Sonde externe (OPS-003) ; offre payante avant des groupes réels. |

Actions **manuelles** de l'utilisateur au prochain déploiement Render : définir `STATOO_TRUSTED_PROXY_HOPS` (ou `STATOO_CLIENT_IP_HEADER`), puis contrôler le build avec `--require-hashes`.

## 5. Ce qui reste à faire

**Lot 2** (Majeurs d'effort M), dans l'ordre du plan ; demande à l'utilisateur lequel traiter :
1. **OPS-001** + TST-001 : CI minimale. Il n'y a aucune CI aujourd'hui.
2. **OPS-002** : `STATOO_API` obligatoire ou défaut non productif ; environnement de recette distinct (service Render et branche Neon dédiés).
3. **MET-001** + TST-003 : distinguer suppression et annulation d'une séance.
4. **MET-005** + UX-002, **MET-006** : code de secours à la création ; écrans manquants côté Flutter (changement de mot de passe ACCESS-03, réglage sport commun, rotation de l'accès collectif).
5. **DAT-006** : écran de reprise si une migration est refusée.
6. **OPS-004**, **OPS-003** (+OPS-008) : sauvegarde et restauration Neon ; logs structurés, crash reporting, `/health` qui vérifie la base.
7. **DAT-005** : fusion de sauvegarde respectant le groupe d'origine.
8. **DAT-004** : purge de l'outbox après acquittement.
9. **PERF-006**, **PERF-007** : redimensionner les photos ; synchronisation différentielle.
10. **A11Y-002** : `GestureDetector` hors tabulation (« Suivant » de l'onboarding, « Voir tout » et « Sauvegarder » de l'accueil, « Photo », choix de restauration, `AppCard(onTap:)`, `team_tab_pill`).
11. **TST-004** : jeu de cas partagé par les trois suites ; **ARC-004** : matrice des rôles unique côté mobile.

Ensuite viennent les mineurs rapides de chaque domaine, puis les lots 3 et 4 (`plan-d-action.md`).

**Restes du lot 1** à proposer quand ils sont liés au constat en cours : voir la colonne « Reste » ci-dessus.

**Questions ouvertes** à faire trancher : `docs/onboarding/questions-ouvertes.md` (portail `web/` à retirer ou non, rôles, branche `main`, etc.).

## 6. Façon de travailler

Pour chaque constat :
1. Lire le constat et le code ; si un choix revient à l'utilisateur, le lui poser.
2. Écrire les tests (tous les scénarios) et constater le RED fonctionnel.
3. Implémenter au minimum ; lancer la suite complète concernée et l'analyse.
4. Revue distincte ; corriger, puis relancer la revue jusqu'au PASS.
5. Mettre à jour `docs/audit/index.csv` (« CORRIGÉ jj/mm/aaaa … (non commité) ») et ajouter une ligne à « Suivi des corrections » dans `plan-d-action.md` : fichiers, tests, résultats, revues, ce qui reste.
6. Si le nombre de tests change, actualiser les compteurs de `CLAUDE.md`, `AGENTS.md` et du `CLAUDE.md` du dossier.
7. Rendre compte en français : ce qui a changé, ce qui est vérifié, ce qui ne l'est pas, et rappeler que rien n'est commité.
