# Corrections UX01–UX08 : spécification de tests avant implémentation

Date : 14 octobre 2026. Référence : [audit et preuves](audit-ui-ux-2026-10-14/rapport.md). Les fichiers de l’audit constituent un historique : ne pas les réécrire après correction.

État après implémentation : [journal RED → GREEN et limites](tdd-majeurs-journal.md), [matrice d’exécution](tdd-majeurs-ui-ux-couverture.csv). Les statuts du paragraphe suivant décrivent la création initiale de ce catalogue ; la matrice contient le statut courant de chaque scénario.

## Contrat TDD

Ce catalogue est écrit avant les corrections applicatives. Il définit les comportements attendus ; il ne constitue pas une déclaration de tests exécutés. **À sa création, tous les cas ci-dessous sont « spécifiés, non exécutés ».** Chaque identifiant devra être relié au test et à son résultat dans le journal d’exécution. Un scénario manuel n’est jamais déclaré automatisé parce qu’un test de service passe.

Pour chaque incrément : écrire le test comportemental → l’exécuter sur le code actuel → constater un échec lié au défaut attendu (RED) → implémenter le minimum (GREEN) → refactoriser si utile → rejouer le test et les régressions pertinentes. Pas de test ignoré pour obtenir du vert, pas d’assouplissement de l’oracle pour suivre l’implémentation. Une erreur d’infrastructure, de compilation ou de fixture n’est pas une preuve RED.

Les huit correctifs forment le périmètre. Les constats modérés ne sont pas automatiquement ajoutés. Une adaptation indispensable à un scénario est tracée explicitement. Aucune opération d’écriture sur les groupes du téléphone : SQLite en mémoire, serveur de test isolé et doubles réseau. Conserver les modifications déjà présentes dans le dépôt.

L’expression « tous les scénarios » signifie ici toutes les partitions de comportement identifiées, leurs limites et les combinaisons à risque. Les valeurs, interruptions et ordonnancements possibles sont infinis : aucune exhaustivité mathématique ni conformité WCAG globale n’est revendiquée. Tout comportement nouveau découvert pendant l’implémentation reçoit son scénario **avant** le code correspondant.

Niveaux : **U** unité ; **DB** intégration SQLite réelle en mémoire ; **W** widget/navigation avec dépendances injectées ; **API** serveur isolé ; **M** appareil/inspection visuelle ou technologie d’assistance. Plusieurs niveaux peuvent être nécessaires pour un même cas.

## Jeux de données communs et oracles

- Groupes `g-alpha` et `g-beta`, noms distincts, paramètres et membres indépendants. Une copie intégrale de leurs tables sert d’oracle de non-mutation, sans dépendre d’un compteur de méthode seul.
- Membres Alice, Benoît, Chloé ; un nom de 120 caractères et deux homonymes avec identifiants différents. Ne jamais rapprocher sur le seul nom dans les nouveaux comportements.
- Séances `s1` et `s2` le 14/10/2026 à 18 h et 20 h ; `s3` le lendemain ; séances classiques et tournois, classées et amicales, brouillons et clôturées.
- Point témoin : tarif 100 F ; Alice cotisation 100 F, pénalité due 20 F/payée 10 F ; Benoît cotisation 50 F ; Chloé 0 F ; don 40 F ; dépense 30 F. Reçus 200 F, dépenses 30 F, variation de caisse +170 F. Soldes de cotisations : Alice 0, Benoît −50, Chloé −100 ; dette pénalité Alice 10. Ces calculs sont des oracles écrits, indépendants du calcul testé.
- Ouverture : caisse 1 000 F, date de départ 01/10/2026 ; Alice avance +200 F et dette pénalité 30 F ; Benoît dette cotisation −100 F ; Chloé solde 0. Les signes sont montrés avec les mots « avance » et « dette ».
- Deux conflits financiers à mêmes versements membres : version A dépense « Terrain » 30 F, version B dépense « Eau » 80 F. Variante : même total et mêmes dépenses, mais payeurs différents. Versions sportives avec mêmes scores et statistiques individuelles différentes ; tournois de même date avec victoires différentes.
- Réseau simulé : succès, réponse retardée contrôlée par `Completer`, refus 403, session 401, conflit 409, indisponibilité/timeout. Aucune attente arbitraire pour simuler une course ; maîtriser les barrières des requêtes.
- Observer, selon le cas : tables, point validé, caisse/dettes, historique et file de synchronisation ; sélection de version et corps exact des requêtes ; route active, valeurs des champs, message accessible et focus. Éviter les seuls tests de présence de chaînes dans le source.

## UX01 — Confirmer le remplacement de toutes les données

Décision de correction : une restauration par remplacement reste possible, mais le choix du fichier ne vaut jamais consentement. Le dialogue nomme le périmètre **tous les groupes locaux**, présente les groupes affectés et distingue le contenu entrant. L’annulation est l’action sûre. Ne pas inventer une importation isolée si le service ne la permet pas.

| ID | Conditions et action | Résultat attendu | Niveau |
|---|---|---|---|
| UX01-01 | Deux groupes ; ouvrir Nouveau groupe puis choisir une sauvegarde valide | Récapitulatif avant toute écriture ; noms des deux groupes et remplacement de toutes les données explicites | W, DB |
| UX01-02 | Annuler ce récapitulatif | Tables, groupe actif, points, marqueurs partagés et file d’attente strictement identiques à l’état initial | W, DB |
| UX01-03 | Fermer par retour système, touche Échap ou extérieur si autorisé | Même effet qu’Annuler ; aucun remplacement implicite | W, M |
| UX01-04 | Annuler le sélecteur de fichier | Aucun dialogue de confirmation, aucune écriture, écran utilisable | W |
| UX01-05 | Fichier invalide, vide ou illisible | Message compréhensible ; données intactes ; possibilité de choisir un autre fichier | W, DB |
| UX01-06 | Confirmer explicitement un fichier valide | Une seule restauration du fichier présenté ; nouveau groupe actif valide ; succès seulement après transaction terminée | W, DB |
| UX01-07 | Appareil sans groupe ; sélectionner une sauvegarde | Contenu entrant visible et confirmation explicite ; aucun faux groupe existant listé | W |
| UX01-08 | Un groupe, plusieurs groupes et noms longs | Liste affectée lisible et déroulable ; actions toujours atteignables ; pas de groupes omis silencieusement | W, M |
| UX01-09 | Deux appuis rapides sur Restaurer/Confirmer ; restauration retardée | Un sélecteur/une confirmation/une transaction à la fois ; feedback d’attente ; pas de succès doublé | W |
| UX01-10 | Échec en milieu de restauration (contrainte DB) | Transaction annulée, données précédentes intactes, erreur et nouvel essai possibles | DB, W |
| UX01-11 | Quitter l’écran pendant lecture de fichier ou transaction | Pas de `setState after dispose`, navigation ou snackbar sur écran détruit ; résultat transactionnel cohérent | W |
| UX01-12 | Même opération depuis Réglages | Même explication du remplacement ; mode fusion conserve son comportement propre et ne se transforme pas en remplacement | W, DB |
| UX01-13 | Changements de groupes entre préparation et confirmation | Périmètre de destruction actualisé ou confirmation invalidée ; ne pas confirmer une liste devenue fausse | W, DB |

## UX02 — Protéger la saisie du point financier

Décision minimale : garde de sortie avec **Continuer la saisie / Abandonner les modifications**. Un retour avec modifications ne perd rien sans accord explicite. Le point validé reste l’unique source des comptes. La persistance d’un brouillon après arrêt forcé est une extension distincte, non promise par cette garde. Elle est recensée ci-dessous comme limite à ne pas confondre avec une réussite.

Une modification se mesure par rapport au dernier point chargé ou enregistré avec succès, sur les valeurs métier ; une recherche et un changement d’onglet ne modifient pas le point. Une erreur de saisie non vide doit également être protégée, même si son parsing donnerait zéro.

| ID | Conditions et action | Résultat attendu | Niveau |
|---|---|---|---|
| UX02-01 | Ouvrir puis revenir sans modification | Sortie immédiate, aucun avertissement | W |
| UX02-02 | Saisir trois cotisations puis flèche retour | Dialogue ; écran non quitté, valeurs intactes ; aucune validation ni publication | W, DB |
| UX02-03 | Même saisie, retour système/geste Android ou retour navigateur applicable | Même garde que la flèche ; pas de contournement du dialogue | W, M |
| UX02-04 | Choisir Continuer, ou fermer le dialogue sans abandon explicite | Rester sur le point, retrouver exactement champs, dépenses et onglet ; zéro écriture métier | W |
| UX02-05 | Choisir Abandonner puis rouvrir | Point précédent intact, saisies abandonnées absentes ; navigation effectuée une fois | W, DB |
| UX02-06 | Modifier séparément cotisation, pénalité payée, pénalité due et motif | Chaque différence déclenche la garde, y compris changement de motif seul | W |
| UX02-07 | Ajouter/supprimer séparément dépense et don | Garde pour chaque modification ; annulation d’un formulaire de mouvement ne crée pas de modification | W |
| UX02-08 | Changer état annulé puis revenir | Garde ; cotisations dues et règle de séance annulée inchangées sans validation | W, DB |
| UX02-09 | Modifier puis restituer toutes les valeurs initiales | Pas de faux avertissement ; ordre de lignes stable ou comparaison indépendante de l’ordre | U, W |
| UX02-10 | Rechercher un membre, changer d’onglet, ouvrir/annuler une modale | Pas de faux état modifié | W |
| UX02-11 | Champ initialement vide : entrer 0, 00 ; champ non vide : effacer | Comparaison métier cohérente ; effacement d’une valeur non nulle protégé | U, W |
| UX02-12 | Texte invalide/valeur hors limites via collage ou contrôleur | Pas de sortie silencieuse due au parsing ; validation explique l’erreur et conserve la saisie | W |
| UX02-13 | Annuler la confirmation de validation du point | Champs conservés ; garde toujours active ; aucune écriture | W |
| UX02-14 | Enregistrer avec succès, revenir immédiatement | Nouvelle référence de comparaison ; pas d’alerte pour des données déjà sauvées ; comptes modifiés une fois | W, DB |
| UX02-15 | Échec de sauvegarde : droit, DB, réseau si nécessaire | Valeurs conservées ; erreur visible ; garde toujours active ; aucune fausse réussite | W, DB |
| UX02-16 | Après succès modifier à nouveau une valeur | Garde de nouveau active ; motif de correction requis lors de la prochaine validation | W |
| UX02-17 | Retours rapides répétés, dialogue déjà ouvert | Un seul dialogue ; aucune double sortie ; Continuer fonctionne | W |
| UX02-18 | Sauvegarde en cours et tentative de sortie | Pas d’abandon ambigu au milieu du commit ; feedback ; sortie possible après résolution | W |
| UX02-19 | Groupe actif changé pendant la saisie | Aucun enregistrement dans l’autre groupe ; message explicite ; valeurs originales protégées tant que l’écran existe | W, DB |
| UX02-20 | Chargement lent ou erreur initiale, puis retour | Pas d’accès à `_point` nul ; retour possible ; pas de faux avertissement | W |
| UX02-21 | Arrêt forcé/OS tue le processus | Limite connue de la garde : aucune garantie de brouillon persistant ; ne pas marquer ce scénario satisfait sans stockage spécifique | M |

## UX03 — Identité distincte des séances et échéances

Décision : référence par défaut unique par groupe et date (`AAAA-MM-JJ-N`), réservée atomiquement à la création ; choisir le plus petit entier strictement positif libre. Pour les anciennes séances sans référence, effectuer une allocation idempotente lors de leur prise en charge. Une référence déjà attribuée reste stable. Une référence partagée explicitement identique conserve le rapprochement intentionnel existant ; ne pas transformer toutes les références historiques en nouvelles échéances. La référence doit être visible en local comme en partagé et le rattachement existant explicite.

| ID | Conditions et action | Résultat attendu | Niveau |
|---|---|---|---|
| UX03-01 | Deux séances locales le même jour, sans référence | Références -1 et -2 ; identifiants canoniques distincts | DB |
| UX03-02 | Trois séances le même jour | -1/-2/-3, aucun écrasement | DB |
| UX03-03 | Préexistence de -1 et -3, création suivante | Allocation -2 ; aucun doublon ; pas d’hypothèse `count+1` | DB |
| UX03-04 | Ouvrir les points en ordre inverse de création | Identités stables, aucune inversion après réouverture ; indépendance des comptes | DB |
| UX03-05 | Appels concurrents pour deux séances | Deux réservations distinctes, aucun alias perdu | DB |
| UX03-06 | Appels concurrents/répétés pour la même séance | Une seule référence et un seul alias ; résultat identique pour chaque appel | DB |
| UX03-07 | Même date dans deux groupes | Chaque groupe a sa propre séquence et ses propres points | DB |
| UX03-08 | Jour suivant, fin de mois, fin d’année | Séquence par date correcte ; format stable | DB |
| UX03-09 | Même date/heure exacte mais identifiants de séances différents | Pas de rapprochement automatique sur l’heure seule | DB |
| UX03-10 | Date fournie par le point ou lue depuis la séance | Même identité pour une même séance ; une date absente ne fabrique pas une date actuelle | DB |
| UX03-11 | Référence explicite personnalisée | Respectée, pas remplacée par une référence générée | DB |
| UX03-12 | Référence explicite identique à une échéance existante | Rattachement annoncé avant consentement ; annuler laisse deux objets initiaux intacts ; confirmer réutilise l’alias prévu | W, DB |
| UX03-13 | Alias historique et points déjà validés | Aucune migration silencieuse, duplication de caisse ou perte d’historique | DB |
| UX03-14 | Deux anciennes séances sans métadonnée de référence | Allocation distincte lors de leur prise en charge ; réouvertures idempotentes | DB |
| UX03-15 | Enregistrer des montants différents dans les deux points | Deux points, deux échéances dues ; changer le second ne change pas le premier ni son historique | DB |
| UX03-16 | Lister les périodes non validées | Deux séances distinctes du même jour restent comptées ; une échéance explicitement liée n’est pas comptée deux fois | DB |
| UX03-17 | Échéance financière seule préexistante, puis séance même date | Réservation évite l’échéance existante sauf rattachement volontaire | DB |
| UX03-18 | Export/restauration puis réouverture | Références, alias et montants restent distincts et stables | DB |
| UX03-19 | Synchronisation sport puis finance, ou inversement | Même référence pour les domaines d’une séance ; deux séances restent distinctes ; file ne fusionne pas les événements distincts | DB, API |
| UX03-20 | Échec transactionnel lors de réservation | Pas de réservation partielle ou d’alias vers un objet inexistant ; nouvel essai sûr | DB |
| UX03-21 | Compte de consultation ouvre seulement une période | Aucun point validé, aucune publication ; les métadonnées d’identité éventuelles ne contournent pas les droits | DB |
| UX03-22 | Création locale, saisie manuelle vide/espaces/référence longue | Référence visible ; espaces normalisés ; défaut sûr ; validation compréhensible selon limites réellement supportées | W |

## UX04 — Comparer les versions avant arbitrage

Décision : chaque version expose auteur, date disponible, contenu métier complet et différences lisibles ; une donnée absente est « non renseignée », jamais inventée. La version choisie et la révision lue sont envoyées explicitement. Ne pas additionner les versions. Les différences sont aussi textuelles, sans dépendre de la couleur.

| ID | Conditions et action | Résultat attendu | Niveau |
|---|---|---|---|
| UX04-01 | Même total membre, dépenses différentes | Libellé et montant de chaque dépense visibles et distinguables | W |
| UX04-02 | Même total, payeurs différents | Détail par membre identifiable ; ne pas confondre homonymes | W |
| UX04-03 | Différences dons : ajout, suppression, montant, motif | Chaque différence consultable dans sa version | W |
| UX04-04 | Différences cotisation, tarif, pénalité due/payée ou motif | Valeurs précédentes/candidates et sens métier compréhensibles ; totaux cohérents | U, W |
| UX04-05 | Version annulée face à version active | État explicite ; pas de réinterprétation comme montant simplement nul | W |
| UX04-06 | Versions sportives scores identiques, buteurs/passeurs/cartons différents | Participants, équipes et compteurs concernés distinguables | W |
| UX04-07 | Tournois même date, victoires A/B/C différentes | Victoires, résultat et noms d’équipes visibles ; pas uniquement « – – – » | W |
| UX04-08 | Différences date, statut, classée/amicale | Ces propriétés sont visibles avant décision | W |
| UX04-09 | Auteur/horodatage disponibles | Identification exacte pour version publiée et chaque candidate ; format français non ambigu | W |
| UX04-10 | Auteur inconnu ou date absente/invalide | Afficher un repli explicite ; conserver identifiant utile ; ne pas planter | U, W |
| UX04-11 | Zéro, une et plusieurs candidates ; liste longue | Pas d’arbitrage vide ; toutes les candidates accessibles ; sélection unique stable au défilement | W |
| UX04-12 | Champ ajouté/supprimé ou liste vide dans une version | Absence distinguée de zéro ; pas de cast nul fatal ; éléments supprimés visibles | U, W |
| UX04-13 | Motif vide ou uniquement espaces, valider | Dialogue conservé avec erreur explicite ; zéro requête ; sélection conservée | W |
| UX04-14 | Sélectionner candidate puis confirmer avec motif | Corps exact : candidate sélectionnée, révision affichée, motif nettoyé ; une requête ; autres versions non additionnées | W, API |
| UX04-15 | Conserver la version publiée | `candidate_id=current` ; résultat métier inchangé ; décision historisée une fois | W, API |
| UX04-16 | Annuler/retour/Échap après sélection et motif | Aucun POST ; aucun document modifié | W |
| UX04-17 | Révision changée pendant comparaison | 409 ; aucune décision sur révision périmée ; expliquer et permettre de comparer à nouveau | W, API |
| UX04-18 | Erreur réseau, 401, 403, attente, double validation | Aucun faux succès ; une opération à la fois ; reprise explicite ; contrôles serveur toujours actifs | W, API |
| UX04-19 | Lecture seule/ADMIN sans PDT/VP ; accès direct | Aucun arbitrage autorisé ; API refuse indépendamment de l’UI | W, API |
| UX04-20 | Écran étroit, texte 200 %, clavier sur motif, lecteur d’écran | Tous les détails/actions atteignables ; versions et sélection correctement annoncées ; différences compréhensibles sans couleur | W, M |

## UX05 — Approuver la proposition effectivement relue

Décision : récapitulatif avant approbation ; confirmation liée à la proposition exacte. Une proposition modifiée entre lecture et clic doit être refusée, même si le bouton était autorisé lors de l’ouverture. Le protocole serveur doit vérifier cette précondition, pas seulement le client.

| ID | Conditions et action | Résultat attendu | Niveau |
|---|---|---|---|
| UX05-01 | PDT ouvre Approuver | Récapitulatif caisse, date, soldes de tous les membres ; aucun POST d’approbation à l’ouverture | W |
| UX05-02 | Soldes +200, −100, 0 et pénalité 30 | Avance/dette/zéro et dette pénalité explicitement distingués ; format F cohérent | U, W |
| UX05-03 | Auteur/date de proposition présents ou absents | Afficher les métadonnées disponibles ; absence déclarée, aucune information inventée | W |
| UX05-04 | Revenir, retour système, Échap ou extérieur | Aucune approbation ni changement de comptes | W, API |
| UX05-05 | Confirmer proposition relue | Une requête liée au contenu/révision relu ; ouverture validée exactement identique ; proposition retirée après succès | W, API |
| UX05-06 | TR remplace proposition A par B avant confirmation de A | Refus 409 ; B n’est pas approuvée ; nouveau récapitulatif requis | API, W |
| UX05-07 | Changement d’un seul montant/date/membre après lecture | Même protection de péremption ; vérifier chaque champ inclus dans la précondition | API |
| UX05-08 | Deux approbateurs confirment en parallèle / double clic | Une seule approbation et une trace ; second résultat explicite, pas de double initialisation | API, W |
| UX05-09 | Proposition absente ou déjà approuvée | Action absente ou indisponibilité expliquée ; pas de crash sur snapshot périmé | W, API |
| UX05-10 | MEMBER/CENSOR/ADMIN/TR sans PDT/VP | Pas de confirmation accessible ; API 403 ; aucune mutation | W, API |
| UX05-11 | VP autorisé, PDT autorisé, rôles combinés | Même parcours de relecture pour tous les approbateurs | W, API |
| UX05-12 | Révocation/expiration entre lecture et clic | Refus explicite ; pas de succès local anticipé | W, API |
| UX05-13 | Réseau lent, échec de POST ou échec de synchro après POST réussi | État d’attente, pas de double POST ; distinguer approbation acquise de rafraîchissement échoué ; nouvel essai sans double solde | W, API |
| UX05-14 | Nombreux membres, homonymes, noms longs, zéro membre renseigné | Tout montant affecté reste consultable ; aucun repli qui présente des données absentes comme validées | W, M |
| UX05-15 | Proposition mal formée côté client | Pas d’approbation aveugle ni d’exception non traitée ; inviter à actualiser | W |
| UX05-16 | Ancien client / requête sans précondition | Refus explicite 422 invitant à actualiser ; aucune approbation sans preuve de la proposition relue ; adapter les clients et fixtures du dépôt ensemble | API |

## UX06 — Même capacité métier dans l’interface et les mutations

Matrice pour un groupe partagé, authentification valide, objet non détenu par un autre responsable. « Membres » inclut créer/modifier/désactiver un joueur. Les autres restrictions existantes (statut séance, propriété, effectif) continuent de s’appliquer.

| Rôles | Membres | Sport | Finance | Paramètres financiers | Arbitrage / ouverture |
|---|---|---|---|---|---|
| MEMBER | consultation | consultation | consultation | consultation | consultation |
| CENSOR | consultation | consultation | consultation | consultation | consultation |
| ADMIN seul | écriture | consultation | consultation | écriture | consultation |
| SG ou SGA | consultation | écriture | consultation | consultation | consultation |
| TR ou TGA | consultation | consultation | écriture | écriture | consultation |
| PDT ou VP seuls | consultation | consultation | consultation | consultation | approbation |
| ADMIN + SG + TR | écriture | écriture | écriture | écriture | consultation |
| VP + SGA + TGA | consultation | écriture | écriture | écriture | approbation |

Le groupe local autonome conserve ses droits locaux, même si une connexion existe pour un autre groupe ; le groupe partagé déconnecté reste protégé. Si cette politique implique une harmonisation de `canWrite` et `requireWrite`, tester les deux et le stockage réel avant modification.

| ID | Conditions et action | Résultat attendu | Niveau |
|---|---|---|---|
| UX06-01 | Chaque ligne de la matrice, chaque domaine | Capacité affichée = autorisation finale ; pas de privilège implicite donné par ADMIN/PDT au sport | U, DB, W |
| UX06-02 | MEMBER/CENSOR : Accueil, Joueurs, fiche joueur, Séances | Actions créer/éditer/supprimer/désactiver/score/clôturer non proposées comme exécutables ; consultation utilisable | W |
| UX06-03 | SG/SGA sur création et détail séance | Mutations sportives possibles sous restrictions métier ; pas de gestion joueurs accordée par erreur | W, DB |
| UX06-04 | ADMIN sur liste/fiche/formulaires joueurs | Gestion joueurs disponible ; commandes sportives non autorisées indisponibles | W, DB |
| UX06-05 | TR/TGA sur écrans sport/joueurs | Lecture seule ; fonctions financières existantes préservées | W |
| UX06-06 | Route directe vers création/édition interdite | Explication avant saisie inutile ; aucun enregistrement ; navigation de sortie accessible | W |
| UX06-07 | Révocation pendant formulaire joueur ouvert | Soumission refusée proprement ; champs conservés ; message rôle requis ; zéro écriture | W, DB |
| UX06-08 | Révocation pendant création/édition sportive | Même refus clair et conservation de saisie ; pas de brouillon partiellement créé | W, DB |
| UX06-09 | Rôle accordé/révoqué après rafraîchissement partagé | UI réagit sans redémarrage ; aucun état de droit périmé conservé | W |
| UX06-10 | Groupe partagé déconnecté puis reconnecté | Pas de mutation hors identité ; motif de reconnexion visible ; droits corrects après reprise | U, DB, W |
| UX06-11 | Identité expirée, invalide ou expirant pendant saisie | Contrôle final refuse ; pas de crash de parsing ni de faux bouton fonctionnel ; texte explicite | U, DB, W |
| UX06-12 | Groupe local autonome, hors connexion | Mutations locales inchangées | DB, W |
| UX06-13 | Groupe local B, identité distante pour A | Pas de droit de A appliqué à B ; politique locale cohérente entre affichage et exécution | DB, W |
| UX06-14 | Groupe partagé A, identité pour B | Pas d’écriture A, même avec rôle ADMIN/SG dans B | DB, W |
| UX06-15 | Séance appartenant à un autre responsable | Pas de mutation directe trompeuse ; éventuel parcours de transfert existant distinct ; garde finale de propriété maintenue | DB, W |
| UX06-16 | Groupe partagé restauré avec marqueur, sans connexion | Protection rechargée depuis DB ; aucune fenêtre d’écriture avant chargement des capacités | DB, W |
| UX06-17 | Doubles soumissions après refus ; réessai après droits rétablis | Pas d’exception non traitée, attente finie ; pas de doublons ; reprise possible | W |
| UX06-18 | Changer rapidement de groupe sur formulaire ouvert | Écriture jamais appliquée au mauvais groupe ; refus clair ou formulaire rattaché à son groupe initial | W, DB |
| UX06-19 | Tester tous les boutons d’un détail : score, participants, compteurs, clôture, réouverture, suppression | Même autorisation à chaque point d’entrée existant ; les confirmations ne contournent pas le contrôle | W, DB |
| UX06-20 | Lecteur d’écran et clavier sur action restreinte | Pas d’action annoncée comme activable à tort ; explication de la restriction consultable | W, M |

## UX07 — Restaurer les tournois sans perdre leur statut

Décision : normalisation selon le type de séance. Les scores classiques nuls d’un tournoi valide ne prouvent pas une absence de résultat. Les anciens résultats classiques `team_a/team_b/draw` et les équipes `a/b` restent normalisés. Un tournoi non exploitable comme résultat clôturé est conservé en brouillon et signalé, sans inventer de résultat ni perdre les autres champs récupérables. Une violation structurelle du schéma reste une erreur transactionnelle, jamais une importation partielle silencieuse.

Fixtures de victoires indépendantes : A=(3,1,0), B=(1,3,0), C=(0,1,3), DRAW_AB=(2,2,0), DRAW_AC=(2,0,2), DRAW_BC=(0,2,2), DRAW_ALL=(2,2,2). Le 0/0/0 doit être testé séparément selon la règle de clôture du tournoi, sans être assimilé arbitrairement au 2/2/2.

| ID | Conditions et action | Résultat attendu | Niveau |
|---|---|---|---|
| UX07-01 | Tournoi CLOSED valide, scores A/B null, victoire A | Restauration conserve CLOSED, type, victoires et résultat A | DB |
| UX07-02 | Paramétrer résultats B, C, DRAW_AB, DRAW_AC, DRAW_BC, DRAW_ALL avec victoires cohérentes | Chacun conserve son résultat et son statut exact | DB |
| UX07-03 | Même tournoi classé puis amical | Drapeau conservé ; l’amical ne rentre pas au classement | DB |
| UX07-04 | Tournoi valide en DRAFT | Reste DRAFT ; pas de clôture automatique | DB |
| UX07-05 | Classique CLOSED avec scores/résultat valides | Statut et classement inchangés | DB |
| UX07-06 | Classique CLOSED sans un score ou sans résultat, combinatoirement | Normalisation historique en DRAFT maintenue ; jamais compté comme match valide | DB |
| UX07-07 | Tournoi sans résultat, victoires manquantes ou résultat incompatible avec les victoires | Reste récupérable en DRAFT, valeurs récupérables conservées, normalisation signalée ; aucun résultat fabriqué ni contribution au classement | DB, W |
| UX07-08 | Sauvegarde ancienne sans `session_type`, résultat legacy | Traitement classique compatible ; aucune colonne inconnue ajoutée au payload | DB |
| UX07-09 | Tournoi avec noms/couleurs A/B/C personnalisés, participations et statistiques | Données identiques après import ; associations joueurs/séance conservées | DB |
| UX07-10 | Remplacement complet d’une sauvegarde mixte, plusieurs groupes | Classiques et tournois conservés selon leurs règles ; aucune contamination entre groupes | DB |
| UX07-11 | Fusion dans groupe existant | Tournoi importé valide ; joueurs remappés ; doublons ignorés selon règle existante ; pas de rétrogradation | DB |
| UX07-12 | Export réel puis restauration dans une autre DB | Comparer statut, résultats, victoires, participations et classement avant/après ; pas uniquement le helper de normalisation | DB |
| UX07-13 | Restauration répétée par fusion | Pas de séance ou contribution au classement doublée | DB |
| UX07-14 | Erreur de contrainte après import d’une première séance | Transaction atomique ; aucune restauration partielle | DB |
| UX07-15 | Vérifier vues de classement et détail de séance restaurée | Tournoi clôturé contribue selon règles métier ; écran présente tournoi et victoires ; pas de bouton de brouillon inattendu | DB, W, M |
| UX07-16 | Point financier et références attachés au tournoi | Statut restauré ne détache ni ne duplique le point financier | DB |

## UX08 — Contrastes réels des composants clair/sombre

Oracles : WCAG 1.4.3, texte ordinaire ≥ 4,5:1 ; texte réellement grand ≥ 3:1 seulement si taille/gras éligibles ; 1.4.11, icônes/éléments graphiques nécessaires ≥ 3:1 avec leur fond adjacent. Ne pas arrondir 4,49 à 4,5 pour faire passer un test. Composer les transparences avant calcul. L’état désactivé est vérifié visuellement et sémantiquement, pas artificiellement assujetti à un seuil textuel exempté.

| ID | Conditions et action | Résultat attendu | Niveau |
|---|---|---|---|
| UX08-01 | PrimaryButton activé clair, libellé 16 px gras | Couleurs effectivement résolues texte/fond ≥ 4,5 ; pas seulement test d’un token inutilisé | U, W |
| UX08-02 | Même bouton sombre | ≥ 4,5 ; contraste sombre existant préservé | U, W |
| UX08-03 | Bouton en attente : libellé/spinner ; pressé/focus/survol si applicable | Texte toujours lisible et indicateur perceptible ; nom accessible cohérent | W, M |
| UX08-04 | Bouton désactivé | État sémantiquement désactivé et visuellement identifiable ; aucune action déclenchée | W, M |
| UX08-05 | Sous-titre groupe du bandeau Joueurs et Séances, clair/sombre | Paire résolue sous-titre/fond ≥ 4,5 sur chaque écran | W |
| UX08-06 | Liens verts 12–16 px sur carte blanche et fond de page clair | Chaque association réelle ≥ 4,5 ; pas de correction limitée au blanc | U, W |
| UX08-07 | Mêmes liens sur fonds sombres utilisés | Lisibilité maintenue ; pas de vert devenu trop sombre par modification globale | U, W |
| UX08-08 | Retour Nouveau groupe et ajout des joueurs initiaux, barre transparente | Icône/fond réel ≥ 3 ; libellés éventuels ≥ 4,5 ; action et tooltip corrects | W, M |
| UX08-09 | Retour sur barre standard verte/sombre | Correction des barres transparentes ne rend pas la barre standard illisible | W |
| UX08-10 | Textes avec alpha/états sélectionnés réellement utilisés | Contraste calculé après composition ; information non portée uniquement par le vert | U, W |
| UX08-11 | Bascule clair/sombre pendant navigation | Widgets mis à jour ; aucune couleur figée de l’ancien thème | W |
| UX08-12 | Texte 100 %, 130 %, 200 % ; 320 et 393 dp | Libellés et groupe lisibles, pas d’overflow ; actions accessibles sans rognage | W, M |
| UX08-13 | Vérifier calcul du ratio : noir/blanc, même couleur, permutation, seuil limite | 21:1, 1:1, symétrie ; ne pas tester les contrastes avec une formule erronée | U |
| UX08-14 | Appareil clair/sombre, forte lumière, TalkBack | Contrôle visuel des associations réelles et des actions ; aucune affirmation de certification générale | M |

## Combinaisons transversales ciblées

| ID | Parcours | Oracle | Niveau |
|---|---|---|---|
| X-01 | UX03 → deux points le même jour → UX02 abandon de l’un | Le premier point enregistré reste intact ; l’autre ne devient pas validé | DB, W |
| X-02 | UX03 → export → UX01 confirmation → UX07 restauration | Références distinctes et tournois clôturés conservés ; annuler ne change rien | DB, W |
| X-03 | UX06 révocation pendant UX02 saisie | Refus d’écriture avec saisie protégée ; pas de rôle gagné par réouverture | DB, W |
| X-04 | UX04/UX05 affichés avec UX08 texte agrandi et thème clair | Données de décision et actions consultables ; sélection/validation non dépendantes de la couleur | W, M |
| X-05 | UX05 validée puis deux points UX03 avec ouverture | Caisse et dettes = ouverture + les deux points ; pas de double initialisation | API, DB |
| X-06 | UX01 restauration d’un groupe partagé → UX06 déconnecté | Consultation possible, aucune écriture autorisée avant reconnexion | DB, W |

## Ordre d’implémentation et critères de sortie

1. **UX07** : intégration de restauration et classement ; périmètre limité et risque de perte historique.
2. **UX01** : garde de l’opération destructive, réutilisation des confirmations sans régression fusion.
3. **UX03** : réservation atomique et rétrocompatibilité, avant les scénarios financiers combinés.
4. **UX02** : garde de saisie, validation et navigation.
5. **UX05** : contrat serveur de précondition, tests API puis récapitulatif mobile.
6. **UX04** : présentation des différences et protection de la décision.
7. **UX06** : matrice des capacités, contrôle final puis tous les points d’entrée UI.
8. **UX08** : paires réellement utilisées, régression clair/sombre et revue sur appareil.

Un correctif est terminé lorsque ses cas de non-régression automatisables prioritaires passent, son critère d’acceptation d’audit est vérifié, les contrôles manuels requis sont tracés (ou explicitement restant à faire), et aucune erreur d’infrastructure ne masque le résultat. Exécuter les tests ciblés avant/après puis les suites affectées ; analyse statique sur les fichiers modifiés. Un test de service ne suffit pas à déclarer un parcours d’écran réparé.

## Répartition des tests exécutables à écrire

Les noms nouveaux ci-dessous sont des cibles prévues, pas des fichiers déjà implémentés. Les tests existants sont étendus plutôt que dupliqués lorsque leurs fixtures conviennent.

| Lot | Tests prévus | Dépendances et points observables |
|---|---|---|
| UX01 | `mobile/test/features/team/create_team_restore_test.dart` ; régressions `mobile/test/features/settings/backup_service_test.dart` | Faux sélecteur avec annulation/erreur/retard ; vraie DB pour l’atomicité ; spy de restauration et route active |
| UX02 | `mobile/test/features/finance/financial_point_screen_test.dart` | Repository et séance injectés ; vraie pile Navigator ; champs lus après tentative de retour ; spy save et file de synchronisation |
| UX03 | `mobile/test/features/finance/finance_test.dart` ; `mobile/test/features/sessions/new_session_screen_test.dart` ; `mobile/test/features/shared/shared_service_test.dart` | SQLite en mémoire, transactions et appels concurrents ; comparaison des deux points et des périodes attendues |
| UX04 | `mobile/test/features/shared/shared_group_screen_test.dart` ; `backend/tests/test_api.py` | Snapshot contenant versions témoins ; capturer chemin/corps du POST ; 409 réel dans API isolée |
| UX05 | `backend/tests/test_api.py` ; `mobile/test/features/shared/shared_group_screen_test.dart` | Deux propositions différentes, clients approbateurs distincts ; aucune écriture avant confirmation ; précondition contrôlée côté serveur |
| UX06 | `mobile/test/features/shared/shared_service_test.dart` ; nouveaux tests de capacités UI joueurs/séances | Paramétrer la matrice ; vraie DB pour refus/propriété ; déclencher changement de `sharedStatusProvider` pendant saisie |
| UX07 | `mobile/test/features/settings/backup_service_test.dart` ; régressions `mobile/test/features/sessions/tournament_3_teams_test.dart` et classement | Export/import réels, deux DB isolées ; lectures des vues et comparaison de fixtures à résultats calculés à la main |
| UX08 | `mobile/test/core/theme/contrast_test.dart` ; widgets boutons/bandeaux/navigation | Résoudre les styles réellement appliqués dans les deux thèmes ; mesurer les paires ; tailles d’écran et TextScaler paramétrés |

Journal de chaque incrément : identifiants couverts ; fichier/nom des tests ; commande ; résultat RED attendu et observé ; fichiers corrigés ; résultat GREEN ; régressions ; contrôle appareil et limites. Écrire « non exécuté » pour une étape non réalisée. Ne pas remplacer l’historique RED par le seul dernier résultat vert.

## Journal initial et limites

- Catalogue créé avant code correctif. Aucun des cas ci-dessus n’est déclaré exécuté à ce stade.
- Audit antérieur : 23 tests Flutter réussis et 8 échecs dans `session_close_test.dart` liés à l’initialisation SQLite. Réparer/injecter la fixture de droits dans ces tests ; ne pas changer la sécurité applicative pour les faire passer.
- Modifications préexistantes dans finance et groupe partagé : conserver leur contenu et leurs tests ; établir le diff avant chaque intervention.
- L’arrêt forcé du point financier (UX02-21), TalkBack, gestes de retour Android, lumière réelle et appréciation de lisibilité exigent une vérification appareil. Les tests widgets ne les certifient pas.
- Les décisions nouvelles sur tournois invalides, approbation avec précondition et rattachement explicite sont spécifiées ci-dessus ; elles doivent être exprimées par des tests avant leur implémentation. Elles ne sont pas présentées comme des comportements déjà vérifiés dans l’application.
