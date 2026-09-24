---
name: commit
description: Règles et format pour effectuer un commit propre et standardisé (Conventional Commits)
---

# Commit Skill

## Contexte
Tu dois toujours suivre ces règles lorsque tu effectues un commit sur ce projet. L'objectif est de maintenir un historique git clair, lisible et standardisé.

## Format des messages de commit
Utilise la convention **Conventional Commits** :
`<type>(<scope>): <description>`

### Types autorisés :
- `feat` : Ajout d'une nouvelle fonctionnalité
- `fix` : Correction d'un bug
- `chore` : Tâches de maintenance (configuration, build, pubspec, etc.)
- `docs` : Modification de la documentation
- `style` : Changements purement esthétiques (typo, formatage, etc.)
- `refactor` : Modification du code (ni feat ni fix)
- `perf` : Amélioration des performances
- `test` : Ajout ou modification de tests

### Règles de la description :
- Écrire en français.
- Utiliser l'impératif, temps présent (ex: "ajoute", "corrige", "modifie").
- Ne pas mettre de majuscule à la première lettre.
- Ne pas mettre de point à la fin.
- Être concis et précis.

### Exemples
- `feat(ui): ajoute l'écran de liste des joueurs`
- `fix(router): corrige la navigation vers le détail de la séance`
- `chore: met à jour les dépendances Flutter`

## Exécution
Pour commiter, exécute d'abord `git add <fichiers>` (ou `git add .`) puis `git commit -m "<message>"`.
