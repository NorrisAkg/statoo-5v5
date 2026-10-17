# Déploiement statique Vercel — 15 octobre 2026

Scénarios écrits avant la configuration, sans modification d'écran.

| ID | Scénario | Résultat attendu |
| --- | --- | --- |
| VER-01 | Détection ou ancien preset Nuxt | Le preset explicite est Other (`framework: null`), sans Nuxt. |
| VER-02 | Build depuis la racine du monorepo | `npm run build:web` produit `web/dist`, sans Python ni build mobile. |
| VER-03 | Installation sur un clone sans cache | `npm ci` utilise le verrou racine ; les scripts nécessaires existent. |
| VER-04 | Régression du portail et production des fichiers | Tous les tests web passent ; HTML, worker, icônes, polices et configuration publique sont produits. |

Résultats observés :

- RED : `node --test web/tests/vercel.test.mjs` : 3 échecs d'assertion,
  paramètres absents (`undefined`), avant création de `vercel.json`.
- GREEN : `npm run build:web` : 41 tests réussis, 0 échec, code de sortie 0 ;
  portail produit dans `web/dist` avec HTML, worker, icônes, polices et config.
- `git diff --check` : code de sortie 0.
- Installation `npm ci` sur clone vierge non exécutée localement ; le test
  vérifie la commande et la cohérence des dépendances avec le verrou.

Le déploiement distant, la connexion à l'API et son CORS restent à vérifier sur Vercel.
