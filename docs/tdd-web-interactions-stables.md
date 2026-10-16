# Lot web — préserver les interactions pendant les actualisations

15 octobre 2026. Complément au lot de protection des brouillons déjà en cours
dans une autre session. Périmètre de cette passe : recherche/filtres des séances,
focus et position de lecture pendant les actualisations et recompositions de
formulaires. Aucun changement de règle sportive ou financière prévu ici.

Tous les scénarios et résultats attendus ci-dessous précèdent le code applicatif.
Tests : `web/tests/interactions.e2e.mjs`, Chrome à 390 et 1440 pixels, API
locale isolée et réponses synthétiques. Aucun compte de production.

| ID | Scénarios prévus | Résultats attendus |
| --- | --- | --- |
| STAB-01 | Recherche et filtre de séances combinés ; actualisation périodique ; nouvelle séance correspondante et séance non correspondante dans la réponse ; filtre ne retournant aucun résultat | Valeurs conservées, liste actualisée et toujours filtrée ; focus, sélection du texte et position de lecture préservés. Un résultat vide ne réinitialise pas les filtres. Contrôle dans les deux tailles et en consultation collective. |
| STAB-02 | Actualisation manuelle, sortie de l’onglet Séances puis retour ; recherche vide et filtre Toutes | Filtre/recherche conservés pour le même compte ; réinitialisation explicite des champs affiche toutes les séances. Aucun état caché ne bloque le retour à la liste complète. |
| STAB-03 | Présence cochée/décochée au clavier ou à la souris dans une liste longue ; changement de format | Contrôle activé reste focalisé et utilisable au clavier ; état de la présence et valeurs déjà saisies sont conservés ; pas de saut en début de formulaire. |
| STAB-04 | Ajout/retrait de dépense ou don dans un point financier ; retrait du dernier mouvement du type concerné | Recomposition conserve focus sur le bouton activé s’il existe encore et position de lecture ; montants déjà saisis conservés. Après retrait, focus sur Ajouter du type concerné. Aucun déplacement arbitraire vers BODY. |
| STAB-05 | Lecture périodique démarrée sans modal ; ouverture d’un formulaire avant sa réponse | Réponse met à jour les données sans reconstruire l’arrière-plan ni voler le focus du formulaire. Une lecture périodique déclenchée alors qu’un formulaire est déjà ouvert ne lance pas de nouvelle lecture. |
| STAB-06 | Déconnexion puis connexion d’un autre compte dans le même onglet | Filtres de l’ancien compte non réutilisés ; brouillons et données privées restent gérés par l’isolation existante. |
| STAB-07 | Nouveau shell PWA après modification des modules | Version de cache renouvelée et nouveau module d’interface précaché ; aucune réponse API privée ajoutée au cache. |
| STAB-08 | Création d’un portail statique dans un dossier temporaire propre, sans secret ni ancien dist ; parcours des imports de son application | Tous les modules importés par l’application sont livrés dans le portail statique. Le nouveau module de conservation des interactions fonctionne aussi après déploiement statique. |

## Preuves

Les exécutions RED et GREEN sont conservées dans
`docs/web-interactions-results/`. Un échec de lancement Chrome ou de serveur
n’est pas une preuve RED. Les tests navigateur ne remplacent pas les essais
manuels TalkBack/VoiceOver, Safari/iOS et installation physique.

## Résultats observés — validation finale du 16 octobre 2026

| Scénarios | RED avant correction | GREEN observé |
| --- | --- | --- |
| STAB-01/02 | Recherche `Atlas` perdue (`''`) après actualisation aux deux largeurs ; résultat vide perdu | Recherche/filtre, focus et sélection conservés, nouveaux documents visibles dans la liste filtrée ; actualisation manuelle et navigation entre onglets conservent les critères |
| STAB-03 | Contrôle de présence perd son focus au premier appui Espace | Présence cochée/décochée au clavier et à la souris, buts saisis conservés, format modifié sans perdre le focus, défilement du dialogue conservé à 390/1440 px |
| STAB-04 | Focus perdu à l’ajout et au retrait du dernier mouvement | Ajout de don/dépense conserve le focus ; retrait ramène au bouton Ajouter correspondant ; cotisation de 300 conservée |
| STAB-05 | La réponse tardive reconstruit le premier enfant de l’arrière-plan (sentinelle supprimée) | Dialogue et saisie intacts ; arrière-plan non reconstruit ; pas de lecture périodique supplémentaire avec un dialogue ouvert |
| STAB-06 | Déjà conforme dans le code initial (régression positive) | Autre compte connecté dans le même document JS : recherche vide et filtre Toutes |
| STAB-07 | Hors connexion, module disponible mais perte du focus dans la composition | Rechargement hors connexion, ouverture de la composition, présence et focus fonctionnels ; shell version `2026-10-15-9`, nouveau module précaché |
| STAB-08 | Module `interaction.mjs` absent du portail statique temporaire | Build isolé et parcours récursif des imports : tous les modules nécessaires livrés |

- RED interactions complet : **10 échecs comportementaux, 1 succès** (`red-browser-complete.txt`). Les variantes qui suivent la première assertion rouge dans un même test n’étaient pas encore exécutées ; elles ont été vérifiées en GREEN.
- RED livraison : **1 échec comportemental**, fichier de module absent (`red-packaging.txt`). Ce scénario découvert pendant l’implémentation a été écrit/testé avant la correction du script de livraison.
- GREEN ciblé final : **12 tests réussis, 0 échec** (`green-browser-final.txt`).
- Régression complète : **45 tests réussis, 0 échec**, dont les parcours API réels sur base en mémoire (`browser-regression.txt`).
- Régression Node : **11 fichiers de tests réussis, 0 échec** dans le résumé du runner (`unit-regression.txt`) ; ce nombre est un décompte de fichiers, pas de scénarios métier.
- Contrôles de syntaxe des modules et `git diff --check` réussis. Formatage des nouveaux fichiers et des sections modifiées appliqué avec Prettier.

La première tentative GREEN a rencontré une erreur de syntaxe, corrigée avant
la validation finale ; son journal `green-browser-first.txt` ne constitue pas une
preuve RED. Une tentative de régression après interruption de la session a échoué
car le serveur local était arrêté (`ERR_CONNECTION_REFUSED`). Le serveur a été
redémarré, sa réponse vérifiée, puis les 45 tests ont réussi.

## Revue dédiée

Revue en lecture seule par un sous-agent conformément à `GEMINI.md` : aucune
anomalie applicative bloquante sur ce périmètre. Un constat de fragilité des tests
a été corrigé : les attentes fixes de 100 ms et l’attente d’une fausse promesse
ont été remplacées par un signal de consommation effective de la réponse HTTP.
La revue de cette correction est validée ; la course réseau reste réellement
provoquée (réponse bloquée, ouverture/saisie, libération). Les 12 tests ciblés
ont été relancés après cette correction.

## Périmètre et limites

Cette session fournit `web/interaction.mjs`, la conservation des critères de
séances par serveur/groupe/compte, les restaurations de focus/défilement, les gardes
de rendu pendant un dialogue et leur livraison PWA. Les protections des
brouillons et soldes, les règles sportives et les changements backend/mobile
présents dans le même arbre de travail proviennent du lot mené dans une autre
session ; ils n’ont pas été réécrits ici.

La recherche reste en mémoire pour la durée du document JS : elle n’est pas
persistée après rechargement. Ce lot ne crée pas de routes ou d’historique de
navigation, de nouvel assistant sportif ni de statistiques supplémentaires.
Les essais physiques Android/iOS, Safari et lecteurs d’écran restent manuels.
Aucun déploiement, commit ou push effectué.
