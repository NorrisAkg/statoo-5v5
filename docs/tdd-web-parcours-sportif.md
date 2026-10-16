# Lot web — parcours sportif progressif

Catalogue initial SPORT-01 à SPORT-15 écrit le 16 octobre 2026 **avant le code
applicatif du lot**. Les cas SPORT-16 à SPORT-19 et les variantes de panne de
stockage découverts ensuite ont été écrits et testés avant leurs correctifs
respectifs.
Références : audit comparatif et lot de stabilité des interactions.

## Périmètre

Assistant Options → Présents → Équipes → Match. Recherche et sélection des
présents, effectifs visibles, répartition équilibrée en nombre, saisie ciblée
des scores/statistiques avec +/−. Conservation de la préparation locale et
des protections de publication existantes. Une séance publiée s’ouvre sur le
match ; les options et la composition restent accessibles.

Aucune modification du barème, du minimum de joueurs, des droits ou du
contrat API. Pas d’envoi automatique au clic +/−. Un brouillon local reste
distinct du bouton « Enregistrer le brouillon », qui publie au groupe.
Les écrans joueurs/statistiques et l’ajout administratif d’un membre restent
dans leurs parcours existants.

## Catalogue prévu et résultats attendus

| ID | Scénarios | Résultat attendu |
| --- | --- | --- |
| SPORT-01 | Nouvelle séance, 390/1440 px, thèmes clair/sombre | Quatre étapes nommées, une seule visible ; début Options ; progression lisible et actions accessibles sans descendre toute la liste ; aucun débordement horizontal |
| SPORT-02 | Suivant/Précédent, accès direct aux étapes ; date/format/référence/classes/options modifiés ; champs requis invalides | Navigation conserve toutes les données ; publication valide la préparation complète et indique l’étape à corriger, sans requête si invalide |
| SPORT-03 | Recherche nom/surnom, casse/accents, résultat vide, effacement | Liste de présences filtrée sans perdre les sélections ; absence de résultats explicite ; aucun champ statistique dans la sélection des présents |
| SPORT-04 | Sélection/désélection collective avec/sans filtre ; répétition ; membres archivés | Action limitée aux membres affichés et éligibles ; pas de doublon ; compteur exact ; archivés absents non sélectionnés ; un archivé déjà participant reste consultable |
| SPORT-05 | Cocher/décocher au clavier, cliquer, changer de format et revenir | Focus/position de lecture préservés pendant les modifications d’une étape ; changer d’étape place le focus sur son titre et remet la lecture au début |
| SPORT-06 | Retirer puis rétablir un présent ayant des statistiques et une affectation | Données retrouvées dans la préparation locale ; le joueur absent n’est jamais envoyé dans les participations ; pas de perte silencieuse de statistiques au retour |
| SPORT-07 | Répartition de 6/7 joueurs en 2 équipes, 6/8 joueurs en 3 équipes ; répétition ; affectation manuelle | Tous les présents placés une seule fois ; écart d’effectif ≤1 ; effectifs et nombre À placer immédiatement actualisés ; identifiants et statistiques conservés |
| SPORT-08 | Passage tournoi → match avec joueurs en C, puis retour ; couleurs identiques | Aucun joueur caché/disparu ; joueurs C deviennent À placer ; clôture bloquée tant que la composition/couleurs restent invalides ; valeurs conservées entre étapes |
| SPORT-09 | Match : scores et statistiques +/−, saisie numérique directe, ouverture d’un autre joueur | Scores/victoires regroupés par équipe ; une seule fiche de statistiques détaillée à la fois ; jamais de valeur négative via − ; buts/passes/cartons distincts ; pas de requête au clic ; focus conservé |
| SPORT-10 | Clôture classique et tournoi, nuls, amicaux, 0 victoire tournoi, minimum du groupe, effectifs inégaux, buts supérieurs au score, passes incohérentes, saisie négative/fractionnaire | Règles existantes préservées via `prepareSport` ; aucune écriture pour invalidité ; message compréhensible et retour vers l’étape concernée ; correction puis récapitulatif possible |
| SPORT-11 | Publication et correction motivée, annulation confirmation, refus 403/422, timeout/conflit | Rien envoyé avant confirmation ; annuler conserve préparation ; contrat API et contexte d’origine inchangés ; succès efface le brouillon local ; refus conserve saisies, timeout garde l’opération, conflit n’est pas annoncé publié |
| SPORT-12 | Fermeture/Échap/rechargement, retour réseau, hors connexion après premier chargement ; brouillon antérieur sans étape | Étape, notes, présents/équipes/stats conservés pour le même compte ; ancien brouillon compatible sans réinitialiser ses données ; publication périmée toujours bloquée |
| SPORT-13 | Séance DRAFT existante, séance CLOSED existante, propriétaire différent, arbitrage, compte collectif/SG/SGA/TR/Admin | Accès rapide au match autorisé seulement au responsable sportif propriétaire sans conflit ; correction et annulation conservent le motif requis ; aucune élévation de droits |
| SPORT-14 | Aucun membre actif, catalogue absent sur séance existante, stockage indisponible après ouverture (sélection et frappe directe) puis rétabli | États vides explicites ; modification existante utilisable sans catalogue ; échec de sauvegarde indiqué immédiatement dans le statut de préparation et l’alerte, jamais « préparation conservée » ; reprise de la sauvegarde et effacement de cette seule erreur lors du rétablissement ; aucun nouvel envoi si stockage refusé |
| SPORT-15 | Mise à jour d’une PWA existante, livraison statique propre et rechargement hors ligne | Version du shell renouvelée, ressources nécessaires livrées et précachées ; pas de cache de réponse privée |
| SPORT-16 | Clic sur le libellé d’un compteur ; lecture du nom accessible ; activation +/− au clavier | Le libellé focalise le champ numérique correspondant, jamais un autre contrôle ; les boutons +/− restent nommés et séparés du label du champ |
| SPORT-17 | Ancien brouillon ou séance existante de tournoi avec points de nul négatifs/fractionnaires, ouvert directement sur Match ; Options invalides dans une création | Publication refusée et retour Options où le champ est visible ; en création, Suivant ne permet pas de quitter Options avec un champ invalide |
| SPORT-18 | Barre d’actions à 320/390 px et hauteur 640 px ; étapes Présents et Match | Tous les boutons restent visibles ; libellés sans mot coupé au milieu ; progression et clôture visuellement principales, publication du brouillon secondaire |
| SPORT-19 | Joueur devenu archivé après sa sélection dans une préparation non publiée ; actualisation, retrait puis réintégration | La ligne reste disponible après retrait pour permettre une réintégration explicite avec ses statistiques ; la sélection collective ne réintroduit pas cet archivé |

## Vérifications prévues

Tests comportementaux navigateur `web/tests/sport-flow.e2e.mjs`. Les tests
de règles existants (`domain.test.mjs`, tests API et audit) restent la référence
des calculs et refus métier ; ils seront exécutés en régression, sans inventer
de nouvelles règles. Les parcours navigateur antérieurs et STAB-03/05/07
seront adaptés pour emprunter les étapes visibles, sans retirer leurs assertions.
Scénarios RED/GREEN et revue conservés dans `docs/web-sport-results/`.

Contrôles visuels : captures aux petites et grandes largeurs dans les deux
thèmes ; actions et texte lisibles. Essais Safari/iOS, clavier virtuel et
lecteurs d’écran physiques à distinguer des tests Chrome automatisés.

## Résultats observés le 16 octobre 2026

| Contrôle | Résultat et preuve |
| --- | --- |
| RED du parcours initial complet | **22 échecs comportementaux, 6 succès** de contrôle des droits ; quatre étapes absentes (`red-sport-complete.txt`) |
| RED du nouveau shell | Ancienne version conservée au lieu de supprimer son cache ; 1 échec, 2 succès (`red-shell.txt`) |
| Premier GREEN du parcours | 27/28 : une erreur de buts refermait la fiche du joueur ; correctif vérifié avec le test conservé (`green-sport-first.txt`, `green-counter-errors.txt`) |
| RED du libellé de compteur | Le label désignait le bouton − désactivé ; clic impossible, cas comportemental et non problème d’environnement (`red-counter-label.txt`) |
| RED du stockage | Statut de conservation trompeur malgré refus : 1 échec puis 2 échecs pour frappe et reprise (`red-storage.txt`, `red-storage-typing.txt`) |
| RED du routage Options | Barème de nul invalide restauré : reste à Match, champ absent (`red-options-validation.txt`) |
| RED du footer | Mot Enregistrer coupé en deux fragments sur petit écran (`red-narrow-actions.txt`) |
| GREEN des cas de revue | **4/4** : panne/rétablissement pendant frappe, Options restaurées invalides, actions étroites (`green-review-cases.txt`) |
| RED du joueur archivé pendant une préparation | Après retrait, ligne absente alors qu’une réintégration explicite doit rester possible : 0 ligne / 1 attendue (`red-archived-draft-explicit.txt`) |
| GREEN de la réintégration | **1/1** : ligne conservée, pas de sélection collective de l’archivé, réintégration manuelle avec ses 2 buts conservés (`green-archived-draft.txt`) |
| Régression navigateur finale | **89 tests réussis, 0 échec**, dont **34 tests SPORT** et les parcours API réels isolés ; environ 179 s (`browser-regression.txt`) |
| Régression Node commune | **12 fichiers de tests réussis, 0 échec** dans le résumé du runner ; décompte de fichiers et non de scénarios métier (`unit-regression.txt`) |
| Régression API | **62 tests réussis, 0 échec**, 1 avertissement préexistant de dépréciation Starlette/httpx ; environ 348 s (`backend-regression-final.txt`) |
| Syntaxe, format et intégrité du diff | `node --check`, Prettier et `git diff --check` réussis |

Une première régression de 84 tests passait avant les derniers cas découverts
(`browser-regression-first.txt`), puis 88 tests avant SPORT-19
(`browser-regression-before-archived.txt`). Les cinq ajouts sont inclus dans la
régression finale de 89 tests. Deux attentes des tests de stockage ont été
corrigées : confirmer effectivement l’envoi avant d’attendre son refus, et lire
le nœud d’erreur masqué plutôt que chercher une alerte visible après reprise.
Ces erreurs de test ne sont pas comptées comme des preuves RED applicatives.

### Couverture comportementale du nouveau parcours

- SPORT-01/02/05 : quatre étapes, navigation, date conservée, focus des
  présences, absence de champs sportifs inutiles dans les autres étapes ;
  390/1440 px, thèmes clair/sombre. STAB-03 conserve son contrôle du défilement,
  de la saisie et du clavier en empruntant les nouvelles étapes.
- SPORT-03/04/06/07 : recherche insensible à la casse/aux accents, résultat
  vide, sélection collective filtrée et répétée, historique archivé, restauration
  de statistiques après désélection, répartition à 6/7 joueurs en deux équipes
  et 6/8 en trois équipes, ajustement manuel et effectifs.
- SPORT-08/09/10 : passage de trois à deux équipes sans cacher les anciens
  joueurs C, score/victoires, statistiques individuelles +/− et saisie directe,
  minimum configurable, déséquilibre et option explicite, couleurs dupliquées,
  buts incohérents, négatifs/décimaux et tournoi sans victoire puis nul.
- SPORT-11/12/13 : récapitulatif sans envoi préalable, annulation de confirmation,
  publication et correction avec contexte/motif, refus 422, réouverture et
  rechargement, hors connexion, ancien brouillon sans étape, version périmée,
  responsabilités et compte collectif. Les scénarios de refus 403, timeout et
  conflit restent couverts par les suites client/audit/API existantes exécutées
  dans la régression ; ils ne sont pas revendiqués comme de nouveaux essais
  sportifs manuels.
- SPORT-14/15/16/17/18 : groupe vide, catalogue absent sur document existant,
  quota refusé pendant frappe puis rétabli, absence de requête si persistance
  impossible, shell/livraison statique/hors connexion, association des labels,
  barème invalide historique et actions aux petites hauteurs.
- SPORT-19 : un joueur archivé après sa sélection dans une préparation non
  publiée reste visible après retrait pour une réintégration explicite. Le
  filtre inclut les participations retirées de cette préparation ; la sélection
  collective continue d’exclure les archivés.

### Intégration avec le travail parallèle

Un autre chat a introduit les modules de chargement des boutons et de validation
Zod pendant la dernière validation. Une passe intermédiaire a eu 4 échecs
(`browser-regression-during-loading.txt`) : deux rechargements hors connexion et
un paquet statique incomplet pendant l’ajout des ressources, puis le test de
coupure de mot qui supposait un texte directement dans `firstChild` du bouton.
La livraison/cache de ces modules a été complétée par l’autre chat. SPORT-18
parcourt maintenant les nœuds texte du bouton pour mesurer le mot, sans
affaiblir la vérification de sa lisibilité.

Après autorisation explicite de l’utilisateur, les deux chats ont coordonné la
validation. Les **89 tests finaux** passent avec les nouveaux modules communs.
Cette commande couvre les neuf suites sportives/PWA indiquées dans le journal ;
elle **n’inclut pas** la nouvelle suite spécifique
`loading-validation.e2e.mjs`, suivie dans l’autre chat. Le shell sportif a été
remplacé par le shell commun loading/Zod, qui conserve les ressources nécessaires
aux deux lots.

Les premières tentatives pytest confinée puis limitée à 120 s n’ont pas fourni
un résultat complet ; elles ne sont pas comptées comme une preuve de défaut
applicatif. L’exécution API finale hors sandbox avec limite de 360 s a terminé
les 62 tests avec succès, sur bases SQLite en mémoire.

## Contrôle visuel et revue dédiée

Huit captures générées dans `web-sport-results/screenshots/` : Présents et
Match à 390 et 1440 px dans les deux thèmes. Inspection des captures mobile
clair/sombre et desktop clair/sombre : texte lisible, une seule étape visible,
footer accessible ; le défaut de coupure de mot observé a été corrigé puis
les captures régénérées. Le test SPORT-18 vérifie aussi 320/390 × 640 px.

Revue dédiée en lecture seule conformément à `GEMINI.md`. Le défaut de routage
des points du nul restaurés et la variante de sauvegarde lors d’une frappe ont
été corrigés après leurs tests RED. Conclusion finale du relecteur : aucun
blocage restant dans le périmètre du lot. Résumé : `web-sport-results/review.md`.

## Limites et état du dépôt

Chrome automatisé ne remplace pas Safari/iOS, le clavier virtuel, les lecteurs
d’écran et l’installation physique sur appareils : ces essais restent à faire.
Les identifiants de participation/statistiques sont conservés par l’état métier
et le contrat existant ; la répartition équilibre le nombre de joueurs, sans
prétendre calculer un équilibre de niveau sportif.

Les changements préexistants du backend/mobile/client/règles ne sont pas
attribués à ce lot. Aucun déploiement, commit ou push effectué.
