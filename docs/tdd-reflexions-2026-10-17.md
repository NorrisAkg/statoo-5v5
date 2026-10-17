# Réflexions restantes — scénarios avant code

L'aperçu fusionné 19095 reste figé pendant le développement sur branche dédiée.

| ID | Cas | Résultat attendu |
|---|---|---|
| REF-01 | Nouveau point financier modifiable | Tous les champs cotisation à zéro sont préremplis au tarif du point ; aucun paiement persisté avant validation. Pénalités inchangées. |
| REF-02 | Effacement impayé, paiement partiel, validation et réouverture | Vide enregistré comme zéro ; réouverture conserve les zéros et montants partiels, aucun remplissage de l'historique. |
| REF-03 | Consultation, tarif zéro, montant déjà présent | Consultation jamais préremplie ; zéro reste vide ; valeurs existantes conservées. Changement de tarif n'écrase pas une saisie. |
| REF-04 | Quitter, échec de sauvegarde, double appui | Préremplissage non enregistré compte comme préparation à valider ; confirmation de sortie ; échec conserve les champs, règles de sauvegarde existantes. |
| REF-05 | Joueur du mois | Préférence personnelle locale, visible par défaut, persistée après redémarrage ; désactivation retire le bloc et son espacement supérieur ; classements/calculs inchangés. |
| REF-06 | Erreur de préférence | Erreur récupérable, pas de succès annoncé ; valeur précédente conservée ; réglage accessible sans rôle de gestion. |
| REF-07 | Clôture classique et tournoi | Message avec vrai nom du gagnant ; nul, égalité à deux et à trois adaptés ; amical également célébré. Aucune modification des points. |
| REF-08 | Annulation/refus/erreur de clôture, simple consultation | Aucune célébration. Un succès ouvre une seule célébration ; pas de relance à la consultation. |
| REF-09 | Animation/accessibilité | Confettis brefs, non interactifs, arrêt à la fermeture ; réduction des animations : message sans confettis. Dialogue défilant, fermeture accessible. |
| REF-10 | Cadrage/régression | Clair/sombre, 320/393, texte 100/130/200, noms longs ; régressions finances, accueil, réglages, clôture. Physique/clavier/lecteur d'écran vérifiés séparément. |

Références lues : design-system, AppTheme/AppCard/PrimaryButton, accueil, réglages, point financier et dialogue de clôture existants.

## Résultats observés

- RED comportemental conservé dans reflexions-red.txt et reflexions-home-red.txt : préremplissage, persistance de préférence, masquage et félicitations manquants.
- GREEN initial : 46 tests ciblés. Régression complète : 458 tests Flutter réussis (reflexions-regression.txt).
- Compléments : 60 tests ciblés réussis (reflexions-final-tests.txt), comprenant tarif zéro, montant partiel déjà présent, abandon de préremplissage et les 12 combinaisons du dialogue 320/393, 100/130/200 %, clair/sombre.
- Build web release réussi dans mobile/build/reflections-web, aperçu distinct sur 19100. L’aperçu utilisateur 19095 reste figé.
- Vérification automatisée du dialogue et des montants ; pas encore de recette visuelle des nouveaux écrans ni clavier physique, zones sûres, lecteur d’écran ou synchronisation réelle multiappareils.
- REF-06 erreur de stockage et REF-08 déclenchement après clôture : branches de code présentes, tests dédiés de panne et recette complète encore à faire. Ne pas présenter ces cas comme automatisés.
- Analyse : aucune erreur de compilation, un import inutilisé corrigé ; remarques de style préexistantes et nouvelles à distinguer du fonctionnement.
- Analyse finale : aucune erreur ni avertissement, sept informations de style (reflexions-analysis-final.txt). Le contrôle navigateur automatisé n’a pas produit de résultat exploitable dans cette exécution ; il ne constitue pas une preuve de recette.

REF-11 (revue avant commit, avant correction) : un point déjà annulé ne reçoit aucun préremplissage. Passer un nouveau point en annulation efface uniquement les préremplissages restés intacts, autorise la validation, conserve les montants saisis manuellement pour éviter toute perte silencieuse.
REF-11 variante découverte en revue, avant correction : sélectionner le montant prérempli sans éditer le texte conserve sa nature automatique ; l’annulation doit toujours le vider et se valider.

Vérification avant commit : 472 tests Flutter réussis sur le lot complet ; revue dédiée ayant découvert REF-11, puis RED observé sur les deux parcours annulés et sur la sélection sans édition. Correctifs vérifiés par les 35 tests financiers complets. Les captures et anciens audits restent hors commit. L’aperçu compilé précédemment ne contient pas encore ce dernier correctif d’annulation.
