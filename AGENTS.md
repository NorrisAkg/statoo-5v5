# Consignes persistantes du projet

## Tests avant le code — instruction utilisateur du 15 octobre 2026

Pour toute correction ou évolution, écrire **tous les scénarios de test du périmètre prévu et leurs résultats attendus avant tout code applicatif**, même pour une modification simple. Couvrir les cas nominaux, variantes, limites, erreurs et régressions pertinents.

Suivre ensuite le cycle TDD : écrire les tests comportementaux, constater leur échec pour la raison attendue, implémenter le minimum nécessaire, puis vérifier les tests et les régressions. Un échec de compilation, de fixture ou d'environnement ne constitue pas une preuve RED.

Si un nouveau cas est découvert pendant l'implémentation, écrire d'abord son scénario et son test avant de modifier le code correspondant. Ne pas ajouter les scénarios après coup pour justifier une implémentation déjà écrite.

Conserver les scénarios et les résultats observés dans le dépôt. Distinguer les tests automatisés exécutés des contrôles manuels restant à faire. Cette règle s'applique à toutes les sessions intervenant sur ce projet.

Voir aussi `docs/conventions.md` pour les conventions du projet.
