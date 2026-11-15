# Brief commun aux sous-agents d'audit Statoo (14/11/2026)

Racine : /home/norris/my-projects/statoo-5v5 — UN SEUL dépôt git (monorepo) : mobile/ (Flutter, référence fonctionnelle, aussi Flutter web), backend/ (FastAPI, backend/app/main.py), web/ (portail JS historique /portal/ + tests Playwright + packaging). Lis d'abord docs/audit/00-cadrage.md.

## Règles impératives
- Lecture seule. Tu n'écris QU'UN fichier : ton rapport docs/audit/<num>-<domaine>.md. Aucune modification ailleurs.
- Git en lecture seule (status, log, diff, show, blame). Aucun commit/add/checkout/stash/reset/etc.
- Ne lis JAMAIS .env*, clés, certificats, credentials (seulement noter le NOM d'une variable).
- Aucun appel réseau vers la production (statoo-api.onrender.com, Neon, Vercel). N'exécute pas scripts/neon_smoke.py ni scripts/check-online-api.py ni les e2e live-integration/group-entry/collective-access/manager-access. N'installe rien.
- Les sorties de commandes déjà exécutées sont dans docs/audit/raw/ (pytest.log, flutter-test.log, dart-analyze.log, test-web.log, build-web.log, prettier.log, npm-audit.log, pip-audit*.log, pub-outdated.log, flutter-build-web.log, flutter-web-size.txt, parcours-*.md éventuellement). Utilise-les plutôt que de relancer des suites longues.
- Chaque constat est PROUVÉ : chemin:ligne (vérifie la ligne), sortie de commande ou étapes de reproduction. Sans preuve → section « Hypothèses à vérifier ». Marque « [déduit] » ce qui est inféré. N'invente aucune règle métier, chiffre, commande ou chemin.
- Si la doc contredit le code, le code fait foi : signale l'écart (constat).
- La doc d'onboarding du 14/11 (docs/onboarding/, docs/architecture/vue-densemble.md, */docs/architecture/analyse.md, */CLAUDE.md) est une SOURCE À VÉRIFIER, pas une preuve. Revérifie ce que tu reprends.
- Français, ton factuel, conventions de la doc existante (dates JJ/MM/AAAA).
- Reste dans ton périmètre ; si tu vois un problème hors périmètre, une ligne en « Renvois vers d'autres domaines ».

## Sévérité
- Critique : faille exploitable, fuite de données, fuite entre tenants, perte de données, parcours principal bloqué, non-conformité bloquante.
- Majeur : risque élevé, bug fonctionnel sur parcours important, accessibilité bloquante pour un groupe, dette qui freine une évolution prévue.
- Mineur : incohérence, friction UX, dette localisée, maintenabilité.
- Info : observation, bonne pratique à généraliser.

## Format du rapport
1. En-tête : domaine, date, méthode (statique / exécuté), limites.
2. Synthèse (5-10 lignes) + note proposée sur 5 avec justification.
3. Tableau récapitulatif : ID | Sévérité | Titre | Fichier principal | Effort.
4. Un bloc par constat :
   ### <ID> — <titre>
   - Sévérité / Domaine / Statut : confirmé | [déduit]
   - Preuve : chemin:ligne + extrait court, ou commande + sortie
   - Impact
   - Recommandation
   - Effort : XS | S | M | L | XL
5. Hypothèses à vérifier. 6. Points positifs (Info). 7. Renvois vers d'autres domaines.
IDs : préfixe imposé dans ta mission, numérotés 001, 002…

## Réponse à la session principale
Au plus 15 lignes : nombre de constats par sévérité, note /5, les 3-5 constats les plus graves (ID + une ligne), limites.

## Environnement d'exécution local (domaines B, D, H uniquement)
- API isolée : http://127.0.0.1:18085 (web/tests/serve.py, SQLite EN MÉMOIRE, CORS_ORIGINS=http://127.0.0.1:18090). Déjà lancée : ne la relance pas, ne la tue pas.
- Flutter web release compilé avec --dart-define=STATOO_API=http://127.0.0.1:18085, servi sur http://127.0.0.1:18090 (python http.server, mobile/build/web). Déjà lancé.
- Le panneau navigateur intégré NE PEUT PAS lancer l'app (SharedWorker sqflite refusé). Utilise Playwright + Chrome installé : `import { chromium } from '/home/norris/my-projects/statoo-5v5/node_modules/playwright/index.mjs'; chromium.launch({channel:'chrome'})`, node = ~/.nvm/versions/node/v22.17.1/bin/node. Exemple fonctionnel : /tmp/claude-1000/-home-norris--claude-spares-spare-wdeBzf/148bbdbf-0d65-4be4-8593-5f759d6736b2/scratchpad/pw/boot.mjs (attendre ~8 s après load).
- Scripts Playwright : dans ton sous-dossier du scratchpad /tmp/claude-1000/-home-norris--claude-spares-spare-wdeBzf/148bbdbf-0d65-4be4-8593-5f759d6736b2/scratchpad/<domaine>/ — jamais dans le dépôt.
- Captures : docs/audit/raw/captures/<domaine>-<nn>-<slug>.png (seule écriture autorisée hors rapport). Garde-les peu nombreuses et utiles.
- Flutter web rend en canvas : pour obtenir un arbre accessible, active la sémantique : `await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click())` puis attends 1 s ; ensuite `page.getByRole(...)`, `page.accessibility.snapshot()` / `page.locator('flt-semantics')`. Sinon clique par coordonnées après capture.
- Chaque contexte Playwright a son propre stockage (IndexedDB) : l'app redémarre vierge (onboarding). Viewports : 393x852 et 320x640 ; thème : `colorScheme: 'dark'|'light'` dans newContext.
- Constaté au démarrage : une erreur console « A bad HTTP response code (404) was received when fetching the script » (à identifier, domaine H).
- Aucune URL autre que 127.0.0.1 ne doit être appelée ; si l'app tente un appel externe (fonts, prod), note-le comme constat (bloque-le avec page.route si besoin).
