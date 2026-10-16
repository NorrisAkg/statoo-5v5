# Prototype de saisie en direct — 16 octobre 2026

## Périmètre proposé

Prototype indépendant, uniquement sur données fictives. Aucun appel à l'API, aucune migration ni modification du parcours réel. Le mode tournoi suit des victoires par équipe et des statistiques cumulées par joueur, sans rencontres individuelles ni équipe « au repos ».

## Scénarios écrits avant code

| ID | Action/état | Résultat attendu |
| --- | --- | --- |
| LIVE-01 | Match : but avec buteur et passeur de la même équipe | Score +1, buteur +1, passeur +1, un événement ; aucune confirmation de sauvegarde intermédiaire. |
| LIVE-02 | But non attribué ou sans passeur | Score/buts cumulés augmentés ; joueur non inventé, aucune passe attribuée. |
| LIVE-03 | Passeur identique au buteur, joueur d'une autre équipe, équipe inconnue | Refus, aucune mutation. |
| LIVE-04 | Tournoi : victoire +1/-1 et but | Victoires indépendantes des buts ; aucun compteur négatif ; pas de sélection de rencontre. |
| LIVE-05 | Carton jaune/rouge | Compteur du joueur concerné et journal mis à jour, sans modification du score. |
| LIVE-06 | Annuler dernière action | Score, victoires et statistiques restaurés ensemble ; annuler sans action ne modifie rien. |
| LIVE-07 | Rechargement / changement de mode | Données de démonstration conservées localement, modes indépendants ; aucune écriture distante. |
| LIVE-08 | Revue finale, annulation, confirmation, reprise | Récapitulatif avant clôture ; annulation conserve les données ; clôture bloque la saisie ; reprise conserve les compteurs. |
| LIVE-09 | Consultation | Tous les résultats visibles, commandes de modification absentes ou désactivées. |
| LIVE-10 | Stockage refusé ou données invalides | Message explicite, ne pas prétendre à une sauvegarde ; possibilité de réessayer ou réinitialiser la démo. |
| LIVE-11 | Clair/sombre, 320/393 px et desktop, texte 100/130/200 % | Pas de débordement horizontal, noms complets accessibles, cibles de 48 px ; dialogues défilants, focus et fermeture au clavier. |
| LIVE-12 | Interruption d'un choix de buteur/passeur | Aucun événement partiel enregistré ; reprise possible. |
| LIVE-13 | Stockage refusé, passage au match puis retour au tournoi | Le statut non enregistré reste visible pour le tournoi ; ne pas afficher une conservation réussie. |
| LIVE-14 | Données locales corrompues | Saisie et clôture bloquées jusqu'à une réinitialisation explicite ; aucun écrasement par une séance vide. |
| LIVE-15 | Vue mobile du tournoi à texte normal | Trois compteurs en lignes compactes, sans disposition deux cartes puis une ; à grand texte, réorganisation sans couper les noms. |
| LIVE-16 | Annulation sur mobile | Commande immédiatement sous les actions de saisie, sans devoir descendre après toute la liste des joueurs ; aucun doublon accessible. |

## Références examinées

## Retours suivants — scénarios avant code

| ID | Action/état | Résultat attendu |
| --- | --- | --- |
| LIVE-28 | Équipe sans but, puis premier but puis annulation | Aucun texte de remplacement dans son camp ; buteur visible après saisie, camp vide après annulation. Si aucun but dans la séance, masquer le cadre vide des buteurs. Match et tournoi, score inchangé. |
| LIVE-29 | Résumé match clair/sombre | Dégradé de référence de SessionHeader : couleur A à gauche, surface centrale, couleur B à droite, teinte 18 %. Écussons, identités et score conservés. Tournoi inchangé. |
| LIVE-30 | Régression | Sélection des équipes, conservation locale, saisie/correction et cadrage 320/393/1200, texte 100/130/200 restent fonctionnels. |

## Retours visuels du 17 octobre — scénarios avant code

| ID | Action/état | Résultat attendu |
| --- | --- | --- |
| LIVE-23 | Résumé du match | Identités avec écusson aux couleurs d'équipe comme SessionHeader, équipes autour du score ; aucune autre modification de disposition. |
| LIVE-24 | Buteurs du match | Aucun titre visible ni nom d'équipe répété ; deux camps conservés avec noms accessibles pour lecteurs d'écran. Tournoi : noms conservés pour distinguer les trois camps empilés. |
| LIVE-25 | 0/1/plusieurs buts, anonyme | Vide explicite ; ballon seul pour 1, ballon suivi de xN pour N>1, nom et nombre annoncés ; aucun changement de score. |
| LIVE-26 | Sélection d'équipe | Un seul onglet actif : coche et mention « Actif », fond et contour renforcés ; clic équipe suivante actualise le repère et les joueurs, y compris en consultation. |
| LIVE-27 | Cadrage | Régression clair/sombre, 320/393/1200, texte 100/130/200 ; noms longs entiers, cibles tactiles conservées. |

## Ajustements acceptés le 17 octobre — scénarios avant code

| ID | Action/état | Résultat attendu |
| --- | --- | --- |
| LIVE-17 | Actions principales | Aucune passe autonome ; nouvelle passe obligatoirement liée à un but. Anciennes passes de démo conservées à la restauration pour éviter une perte silencieuse. |
| LIVE-18 | Résumé match/tournoi | Match : équipes autour du score central ; bloc « Buteurs de la séance » séparé, deux colonnes ; tournoi : victoires modifiables et buteurs par équipe empilés. Buts anonymes signalés. |
| LIVE-19 | Choix du passeur | Titre « But de … », question « Qui lui a fait la passe ? », choix « Aucun passeur ». Retour au buteur sans écriture, annulation/Escape sans but partiel. |
| LIVE-20 | Correction depuis le journal | Modifier un but existant (buteur/passeur), sans doubler score ni événement ; annulation inchangée, persistance après rechargement. Refus du même joueur, autre équipe, événement absent et séance clôturée. |
| LIVE-21 | Régressions | Consultation/clôture bloquent les corrections ; matrice clair/sombre, 320/393/1200 et texte 100/130/200 ; compteurs, sauvegarde, annulation précédents conservés. |
| LIVE-22 | Modifier un but d'une autre équipe puis annuler/Escape | L'équipe sélectionnée et celle des nouvelles actions restent identiques ; édition sans changer la sélection de saisie. |


`docs/design-system.md`, thème Flutter actuel, AppCard, PrimaryButton, SessionDetailScreen et NewSessionScreen. Captures vues : `08-seance-detail-s9.jpg` et `04-seances-nouvelle.jpg`. Elles guident la hiérarchie, sans réintroduire les débordements ou anciennes conventions.

## Arbitrages à discuter

- Pas de sauvegarde manuelle par statistique : événement complet puis conservation locale immédiate dans la démo.
- Le tournoi affiche les trois équipes, les victoires et les statistiques cumulées. Ajouter un but ne donne pas automatiquement une victoire.
- Un but peut rester non attribué ; le choix d'un passeur est facultatif. Les cartons ne modifient pas le score.
- Le journal et l'annulation portent sur l'action complète, y compris sa passe éventuelle.
- Seule la fin de séance comporte un récapitulatif et une confirmation.

Les contrôles navigateur, captures réellement vues et limites seront consignés après vérification. Pas de validation implicite pour l'application de production.

## Aperçu et vérifications

### Ajustements du 17 octobre

LIVE-28/29 : RED comportemental « Aucun but » encore présent avant correction. Après correction, 15 tests réussis incluant la régression de cadrage ; le camp vide ne contient plus de texte et le cadre sans aucun but est masqué. Dégradé vu à 393 px sombre, capture `mobile/build/live-prototype/gradient-empty.png` ; clair contrôlé automatiquement. Limites physiques inchangées.

Retours visuels LIVE-23 à 27 : deux tests rouges avant code (écussons absents, repère actif absent), puis **14/14 tests verts**, commande précédente complétée avec `visual-feedback.test.mjs`. Régression automatisée des 18 combinaisons clair/sombre × 320/393/1200 × texte 100/130/200. Rendu réellement vu : match à 393 px sombre, deux buts Karim, écussons, ballon x2 et onglet actif. Capture `mobile/build/live-prototype/feedback-dark.png`. Dispositif physique et lecteur d'écran non contrôlés.

RED observé avant code : passe autonome acceptée par le modèle et bouton encore présent (deux assertions comportementales en échec). GREEN : suite étendue à 12 tests, dont correction atomique du but et conservation des anciennes données de démo. Commande : ajouter `web/prototypes/live-stats/adjustments.test.mjs` à la commande ci-dessous.

Rendu réellement vu à 393 px clair : résumé avec score central/buteurs et dialogue contextualisé avec annulation et retour. Captures `mobile/build/live-prototype/adjusted-summary.png` et `adjusted-dialog.png`. Matrice automatisée existante réussie ; limites appareil physique/clavier/lecteur d'écran inchangées. Aucune intégration au produit ni publication.

Revue dédiée : LIVE-22 a reproduit une désynchronisation de l'équipe après annulation de correction (équipe attendue Union, Racing obtenu). Test écrit et rouge avant correction ; l'équipe de correction reste maintenant indépendante de la sélection de saisie, test vert.

Aperçu local : http://127.0.0.1:19094/prototypes/live-stats/. Serveur dédié sur web/, aucune utilisation du serveur ou de la base de données réels.

Tests : `node --test web/prototypes/live-stats/model.test.mjs web/prototypes/live-stats/prototype.e2e.mjs web/prototypes/live-stats/review.e2e.mjs` — **10 tests réussis**, dont la matrice 320/393/1200 px, clair/sombre et texte 100/130/200 %. Test réseau : aucun appel groupes/auth/API distante. Les premiers essais ont utilisé un port déjà occupé par un autre aperçu : échecs d'environnement exclus de la preuve RED.

Preuve RED du modèle : compteurs restant à zéro, sélections invalides acceptées. Puis GREEN après implémentation. La revue a reproduit LIVE-13/14 (faux statut après quota, clôture écrasant une préparation illisible), tests ajoutés avant correction ; cas désormais verts. LIVE-15/16 a révélé la grille deux-plus-une sur mobile, remplacée par trois lignes avec annulation proche des commandes. Revue dédiée finale validée.

Captures vues : 1200 px sombre et 393 px clair/sombre ; dialogue passeur et récapitulatif final à 393 px sombre. Captures conservées localement dans mobile/build/live-prototype/. Les tests de grand texte contrôlent le cadrage et les cibles de 48 px ; ils ne constituent pas une validation TalkBack/VoiceOver.

Non couvert : appareil physique, encoches/zones sûres réelles, clavier virtuel et lecteur d'écran. Pas d'intégration Flutter, de synchronisation réseau ni de publication. Les sauvegardes de démonstration sont limitées à la même origine et peuvent être effacées par le navigateur.
