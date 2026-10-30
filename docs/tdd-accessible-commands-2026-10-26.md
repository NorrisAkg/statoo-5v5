# F08 — Noms accessibles des commandes

## Références lues avant modification

`docs/design-system.md`, AppTheme et ses variantes, PrimaryButton/AppCard,
écrans Joueurs/Séances et parcours Création de groupe/Effectif/Composition.
Le thème Poppins et les composants Flutter communs restent la référence.

## Scénarios et résultats attendus définis avant code applicatif

- A11Y01 : les retours de création de groupe et d'effectif, lorsqu'une route
  précédente existe, annoncent Retour et fonctionnent ; aucune commande retour
  fantôme à la racine.
- A11Y02 : le retrait initial annonce « Retirer <nom complet> du groupe » et
  supprime le membre visé seulement ; les autres lignes conservent leurs noms.
- A11Y03 : le FAB de séances annonce « Nouvelle séance » et ouvre le parcours ;
  un compte en lecture seule ne reçoit aucune commande de création autorisée.
- A11Y04 : chaque commande Présent annonce « Marquer <nom complet> présent » ;
  l'activation remplace cette commande par la composition du bon joueur.
- A11Y05 : chaque segment annonce « Équipe A/B/C pour <nom complet> », conserve
  rôle bouton, action tap, état selected et le vrai comportement d'affectation/
  désaffectation. C n'existe qu'en tournoi ; ne pas dupliquer les actions sémantiques.
- A11Y06 : le retrait de composition annonce « Retirer <nom complet> de la séance »
  et rend ce joueur absent sans affecter les autres.
- A11Y07 : la recherche conserve un nom de champ stable « Rechercher un joueur »
  à vide et après saisie ; elle ne regroupe pas les noms et commandes des joueurs.
  Recherche par nom/surnom et effacement toujours fonctionnels, sans perte des
  affectations. Conserver la navigation clavier des widgets natifs.
- A11Y08 : clair/sombre, 320/393 dp, texte 100/130/200 %, clavier/zones sûres,
  nom long et tournoi/classique : aucune nouvelle exception de cadrage ; noms
  accessibles complets et actions atteignables. Distinguer tests et rendu observé.
- A11Y09 : vérifier les noms et les actions dans le vrai build Flutter web, au
  clavier, et conserver captures/observations. Pas de prétention de recette
  TalkBack/VoiceOver physique ni de certification d'accessibilité.
- A11Y10 (précision avant code applicatif) : le parcours réellement modifiable
  révèle des débordements du bandeau d'étapes à petit écran/grand texte. Faire
  tenir ses libellés, le compteur/« Tout cocher » et les commandes de composition (classique et tournoi) par
  retour à la ligne, sans réduire le texte ni masquer une commande.
- A11Y11 (découvert au contrôle Chrome, avant test/correction) : à 320×568 et
  texte 200 %, le pied fixe absorbe la page et le défilement précédent est
  conservé au changement d'étape. Placer bandeau et actions dans le contenu
  défilant à grand texte/clavier, empiler les actions sans couper les mots et
  recommencer chaque étape en haut, en conservant les saisies et sélections.
- A11Y12 (inspection des captures, avant test/correction) : le label de recherche
  doit rester intégralement peint à texte 200 %, et « Précédent » doit tenir sans
  coupure à 320 dp. Tester avec les fichiers Poppins réellement embarqués ; ne
  pas confondre métriques de police de test et rendu de production.

## Périmètre

Même application Flutter web/mobile. Aucun changement métier, droit, parcours ou
suppression supplémentaire. Noms sémantiques contextualisés sans rallonger les
petits libellés des boutons ; label de recherche permanent selon la convention de
champ. Aucun remplacement global des widgets ni retrait de leurs sémantiques.

## Résultats

- RED initial : 31 échecs comportementaux et 1 succès, noms/commandes manquants,
  recherche regroupée et débordements du parcours modifiable.
  `accessible-commands-red-2026-10-26.txt`.
- Complément de revue A11Y11 : défilement conservé à 289 px au lieu de 0,
  `accessible-commands-review-red-2026-10-26.txt` ; test écrit avant correction.
- Complément visuel A11Y12 : 3 échecs avec les fichiers Poppins embarqués
  (label tronqué à 320/393 dp, mot Précédent sur plusieurs lignes à 320 dp),
  `accessible-commands-labels-red-2026-10-26.txt`, puis 3 succès dans
  `accessible-commands-labels-green-2026-10-26.txt`.
- GREEN final : **49 tests ciblés réussis en 54 s**, dont 36 nouveaux cas et 13
  tests existants des écrans modifiés, `accessible-commands-green-2026-10-26.txt`.
  Les métriques finales utilisent les polices Poppins embarquées.
- Contrôle complémentaire du focus à l'ouverture/fermeture du clavier à texte
  normal : succès, `accessible-commands-focus-2026-10-26.txt`.
- Analyse finale des quatre sources et du nouveau module de tests : aucun
  diagnostic, `accessible-commands-analyze-2026-10-26.txt`.
- Régression Flutter finale : **952 tests réussis en 3 min 20**, code applicatif
  figé, `accessible-commands-regression-final-2026-10-26.txt`. Les premières
  exécutions globales précédant les constats de rendu ne sont pas la validation finale.
- Build release web final : compilation réussie (227 s),
  `accessible-commands-build-2026-10-26.txt`.
- Contrôle Chrome final : **4 configurations réussies en 104 s**, sans exception
  JavaScript, clavier Entrée, recherche par saisie réelle et nom long sélectionné.
  Largeurs 320/393, texte 100/200 %, clair/sombre, classique/tournoi. Captures
  finales inspectées et limites détaillées dans
  `accessibility-2026-10-26/observations.md` ; log
  `accessible-commands-browser-2026-10-26.txt`.
- Revue distincte : `review-accessible-commands-2026-10-26.md`, points A11Y11/12
  corrigés en TDD, ainsi que le rendu A11Y12 ; aucun blocage restant identifié
  dans le périmètre après contrôles finaux.

La fixture des tests ne demande plus un SemanticsHandle supplémentaire (le runner
le fournit), et révèle les contrôles par défilement avant activation. Ces ajustements
ne sont pas comptés comme des défauts applicatifs RED. L'expiration initiale du
contrôle automatique d'autorisation des tests a été résolue par une relance ; aucun
test n'est déclaré exécuté sur la base de cette tentative non démarrée.
