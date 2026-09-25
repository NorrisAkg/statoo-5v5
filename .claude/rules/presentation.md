---
paths:
  - "lib/features/*/presentation/**"
  - "lib/core/widgets/**"
  - "lib/core/theme/**"
---

# Couche présentation

- Couleurs via `context.colors.<token>` uniquement ; aucun `Color(0x…)` ni `Colors.xxx` en dur (seule exception tolérée : illustrations de l'onboarding). Les deux thèmes (clair/sombre) doivent rester lisibles.
- Fonds teintés = couleur à 15 % d'opacité + texte dans la couleur pleine. Rayons 12/16/20/pilule, marges écran 16, grille de 4.
- Icônes `Remix.*` (`package:remixicon/remixicon.dart`, variante `_line`, `_fill` pour l'onglet actif). Pas d'icônes Material en remplacement.
- Dates : `DateFormat(..., 'fr_FR')`. Libellés en français, écrits directement.
- Réutiliser `core/widgets/` avant de créer un composant ; un composant utilisé par 2 features va dans `core/widgets/`.
- Lire l'état par `ref.watch(provider)` et gérer les trois états `AsyncValue` (`when`/`switch`). Muter via le contrôleur de la feature, jamais le repository directement.
- `BuildContext` après un `await` : garde `if (!context.mounted) return;` (ou `mounted` dans un `State`).
- Navigation : `context.push('/seances/$id')` pour les écrans hors onglets, `context.go` pour changer d'onglet. Nouvelle route = déclarée dans `core/router/app_router.dart`.
- Design : la capture de `statoo-captures/` correspondante prime ; la comparer après chaque écran terminé (agent `design-fidelity`).
