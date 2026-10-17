# Conventions

Conventions constatées au 12 octobre 2026.

## Code et organisation

- Fonctionnalités sous lib/features/<feature>, couches domain/data/application/presentation selon besoin.
- Règles testables dans domain ; interfaces de repositories actuellement dans data.
- Imports relatifs dans lib, package:statoo dans test.
- Providers surtout manuels ; annotations dans router/thème. Suivre le fichier voisin.
- Regénérer *.g.dart/*.freezed.dart, sans édition manuelle.
- Observer le groupe actif et transmettre teamId aux repositories.
- Examiner les invalidations des données dérivées à chaque mutation.

Sources : `analysis_options.yaml`, `lib/features/players/application/players_provider.dart`, `lib/features/sessions/application/sessions_provider.dart`, `lib/core/router/app_router.dart`.

## Interface et analyse

**Lecture obligatoire avant chaque écran, refonte, dialogue ou feuille modale : [mémoire du design](design-system.md).** Cette mémoire décrit les références visuelles, composants, couleurs, typographie et vérifications de cadrage. Le rappel persistant se trouve dans `AGENTS.md` et s’applique aux prochaines sessions.

Couleurs généralement via context.colors/ThemeExtension ; composants partagés dans lib/core/widgets. Poppins embarquée, thèmes clair/sombre, Remix Icon, interface française et intl. Les libellés restent dans les widgets, sans catalogue ARB trouvé. Les consignes historiques Inter/couleurs uniquement dans le thème ne décrivent pas intégralement le code : les avatars ont une palette locale.

Very Good Analysis est le jeu de règles actif, adapté notamment pour les imports et la documentation publique. Générés/build/projets natifs sont exclus de l'analyse. Les anciens chiffres d'analyse ne sont pas une mesure actuelle. Commentaires français/anglais ; commits récents majoritairement Conventional Commits avec scope.

Sources : `lib/core/theme/app_theme.dart`, `lib/core/widgets/initial_avatar.dart`, `lib/main.dart`, `analysis_options.yaml`, historique Git.

## Workflow et références

### TDD — instruction utilisateur du 14 octobre 2026

Précision utilisateur du 15 octobre 2026 : **tous les scénarios de test du périmètre prévu et leurs résultats attendus doivent être écrits avant tout code applicatif**, même pour une modification simple. Inclure les cas nominaux, variantes, limites, erreurs et régressions pertinents. Pour tout cas découvert ensuite, écrire son scénario et son test avant le code correspondant. Cette consigne persistante figure également dans `AGENTS.md` à la racine et s'applique à toutes les sessions du projet.

Les corrections et évolutions suivent désormais le TDD : scénarios et résultats attendus écrits avant le code applicatif, test comportemental qui échoue pour la raison attendue, correction minimale, puis refactorisation et régression. Un échec de fixture, de compilation ou d'environnement ne constitue pas une preuve du défaut. Ne pas annoncer un scénario exécuté sans résultat observé ; distinguer tests automatisés et contrôles sur appareil.

Le premier lot couvre les huit majeurs de l'audit UI/UX : [catalogue de scénarios](tdd-majeurs-ui-ux.md). Conserver la traçabilité entre identifiant du scénario, test, preuve RED et résultat GREEN. Toute nouvelle règle découverte reçoit son scénario avant implémentation.

CLAUDE.md et GEMINI.md demandent une revue dédiée après implémentation avant commit. Pour un commit demandé, consulter la compétence .agents/skills/commit/SKILL.md. Aucun commit n'a été réalisé pour cet onboarding.

Les règles Windows sont dans .agents/rules/powershell_windows.md. Les consignes persistantes pour les agents sont dans `AGENTS.md` à la racine du dépôt.

CDC pour les règles initiales, captures pour le design ; extensions et divergences dans [le registre](decisions-and-risks.md). Une intention produit ne doit pas être déduite de la seule présence de code.

Sources : `CLAUDE.md`, `GEMINI.md`, `.agents/rules/powershell_windows.md`, `specs/prompt-agent-flutter-statoo.md`.
