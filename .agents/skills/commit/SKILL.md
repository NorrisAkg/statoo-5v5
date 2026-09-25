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
- Écrire en anglais.
- Utiliser l'impératif, temps présent (ex: "add", "fix", "modify").
- Ne pas mettre de majuscule à la première lettre.
- Ne pas mettre de point à la fin.
- Être concis et précis.

### Exemples
- `feat(ui): adds the player list screen`
- `fix(router): fixes the navigation to the session detail`
- `chore: updates the Flutter dependencies`

## Exécution
1. Exécute d'abord `git add <fichiers>` (ou `git add .`)
2. Puis `git commit -m "<message>"`
