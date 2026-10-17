# Ordre de première visite

Scénarios écrits avant code applicatif :
- ORD01 : première visite sans groupe : splash puis présentation, sans bienvenue anticipée. Passer mémorise la fin puis affiche bienvenue.
- ORD02 : les trois étapes puis Commencer affichent bienvenue ; repasser par le splash ne rejoue pas la présentation.
- ORD03 : liens bienvenue, rejoindre et créer sans présentation terminée sont redirigés vers onboarding ; navigation seule ne mémorise rien.
- ENT01/03 : après présentation, rejoindre ouvre la connexion et conserve installation=1.
- ENT02 : après présentation, créer ouvre la création partagée.
- Régressions : visite déjà effectuée sans groupe ouvre bienvenue, groupe existant conserve accueil ; persistance SharedPreferences existante ; cadrage existant inchangé.

Aucune composition visuelle modifiée. Références lues : design-system, thème, AppCard/PrimaryButton, splash, onboarding et bienvenue.

## Résultats observés
- RED : les 5 nouveaux tests échouent sur l'absence de la première étape attendue (onboarding-order-red.txt).
- GREEN : 81 tests passent (entrée, onboarding, smoke et cadrage 320/393, 100/130/200 %, clair/sombre), onboarding-order-green.txt.
- Les animations continues de présentation nécessitent des attentes bornées dans les tests ; pumpAndSettle ne peut pas terminer sur ces étapes.
- git diff --check : réussi.
- Limites : aucune nouvelle recette visuelle navigateur/appareil, aucun déploiement public effectué. Les tests de cadrage ne constituent pas une validation visuelle.
- Comportement : présentation terminée ou passée mémorisée localement ; effacer les données ou utiliser un autre navigateur/appareil réinitialise cette première visite. Présentation interrompue non mémorisée.
- Revue dédiée statoο-reviewer : aucun défaut bloquant. Reprise par splash testée dans le même conteneur ; rechargement persistant vérifié dans main.dart, redémarrage physique non testé.
- Analyse statique ciblée avant commit : aucun problème ; nouvelle exécution des 81 tests réussie après corrections de lint.
