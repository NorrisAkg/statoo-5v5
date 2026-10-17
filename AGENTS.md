# Consignes persistantes du projet

## Parité web et mobile — instruction utilisateur du 16 octobre 2026

Tous les processus doivent suivre les mêmes étapes, actions explicites, confirmations, validations et statuts dans les deux environnements, **y compris le mode local sans compte et les sauvegardes/restaurations**. Le mobile est la référence des parcours ; ne pas inventer un raccourci web qui saute le démarrage d'une séance ou une autre transition métier.

Le point d'entrée `mobile/lib/main_web.dart` réutilise l'application Flutter, ses écrans et ses règles. Réserver les adaptations de plateforme au stockage navigateur, au transport et aux fichiers. L'ancien portail sous `web/` est conservé pour la transition et les préparations historiques ; ce n'est pas une seconde référence fonctionnelle. Contrat, scénarios, résultats et limites : `docs/parite-web-mobile.md`. Tester la reprise interappareils et les refus/conflits, pas uniquement la présence de boutons similaires.

## Tests avant le code — instruction utilisateur du 15 octobre 2026

Pour toute correction ou évolution, écrire **tous les scénarios de test du périmètre prévu et leurs résultats attendus avant tout code applicatif**, même pour une modification simple. Couvrir les cas nominaux, variantes, limites, erreurs et régressions pertinents.

Suivre ensuite le cycle TDD : écrire les tests comportementaux, constater leur échec pour la raison attendue, implémenter le minimum nécessaire, puis vérifier les tests et les régressions. Un échec de compilation, de fixture ou d'environnement ne constitue pas une preuve RED.

Si un nouveau cas est découvert pendant l'implémentation, écrire d'abord son scénario et son test avant de modifier le code correspondant. Ne pas ajouter les scénarios après coup pour justifier une implémentation déjà écrite.

Conserver les scénarios et les résultats observés dans le dépôt. Distinguer les tests automatisés exécutés des contrôles manuels restant à faire. Cette règle s'applique à toutes les sessions intervenant sur ce projet.

Voir aussi `docs/conventions.md` pour les conventions du projet.

## Design — mémoire persistante, instruction utilisateur du 15 octobre 2026

Avant toute création, refonte ou modification d’un écran, **lire `docs/design-system.md`**, puis examiner le thème actuel, les composants partagés et au moins deux écrans de référence du même parcours. Cette étape s’applique aussi aux dialogues, feuilles modales et états secondaires.

Respecter cette référence dans les nouveaux écrans. Vérifier séparément la cohérence visuelle et le cadrage : clair/sombre, 320/393 dp, texte 100/130/200 %, clavier et zones sûres, noms/montants longs et permissions. Écrire les scénarios avant le code selon la règle TDD ci-dessus. Ne jamais déclarer un écran validé visuellement sur la seule base de son code ou de tests sans débordement ; indiquer ce qui a été vu à l’écran, automatisé et non couvert.

Conserver les nouveaux arbitrages de design dans `docs/design-system.md` et leurs preuves dans un suivi de vérification. Ne pas reprendre une ancienne convention (notamment Inter ou un thème sombre unique) qui contredit cette mémoire et le thème actuel.
