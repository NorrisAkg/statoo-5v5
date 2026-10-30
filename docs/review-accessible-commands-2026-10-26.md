# Revue distincte après implémentation — F08

## Périmètre relu

Création du groupe, effectif initial, liste des séances, composition modifiable.
Relecture des noms sémantiques, callbacks de sélection/retrait, filtre de recherche,
permissions existantes, disposition des étapes et commandes, gestion de focus et
état du formulaire. Références de design et composants lues avant code ; décision
persistée dans `docs/design-system.md`.

## Constats

- Les tooltips natifs nomment les commandes isolées ; les Text.semanticsLabel
  contextualisent Présent et A/B/C sans changer leurs libellés visuels. Le rôle,
  l'action tap et l'état selected des SegmentedButton sont conservés. Les tests
  activent de vrais événements sémantiques, pas seulement une inspection de widgets.
- Le bouton Nouvelle séance conserve sa garde de permission ; la consultation
  n'obtient pas de commande de création. Les contrôles métiers des providers ne
  sont pas déplacés ou contournés par le nouveau nom accessible.
- La recherche est isolée par une frontière Semantics et conserve un label après
  saisie. Les tests vérifient filtrage nom/surnom et effacement. Les labels des
  joueurs ne sont plus inclus dans le nom du champ exposé.
- L'empilement des commandes de joueur conserve exactement les callbacks et
  valeurs d'affectation/retrait. Les libellés complets restent sémantiques même
  lorsque l'affichage utilise une lettre d'équipe.
- Le contrôle du parcours modifiable a mis en évidence des débordements que la
  seule présence d'un écran en consultation ne couvre pas : bandeau, compteur et
  commandes sont adaptatifs sans plafonner le facteur de texte.

## Point trouvé au contrôle du vrai rendu

À 320×568 et texte 200 %, le pied fixe absorbait la page et le défilement de
l'étape précédente persistait (289 px au lieu de 0 dans A11Y11 RED). Le scénario
et le test ont précédé la correction : bandeau/pied défilants à grand texte ou
clavier, actions empilées, clé de liste par étape. Les clés/indices du contenu
restent stables quand seul le clavier change, pour ne pas détruire l'éditeur.
Le texte saisi et le focus sont contrôlés à texte normal et agrandi.

L'inspection des captures a également révélé une ellipse sur le nouveau label de
recherche à texte 200 % et une coupure du mot Précédent à 320 dp. A11Y12 a été
décrit puis exécuté avant correction, en chargeant les vrais fichiers Poppins :
les trois tests échouaient sur le paragraphe tronqué ou la hauteur multiligne.
Label flottant permanent, espace décoratif compacté (hauteur minimale du champ
48 px) et empilement/défilement sous 360 dp corrigent ces cas sans limiter le
facteur de texte. Les trois tests passent. L'icône compactée n'est pas une cible
interactive ; la zone de saisie conserve sa hauteur et toute sa largeur.

## Limites

Les assertions Flutter vérifient noms, flags, actions et absence de débordement ;
elles ne constituent pas une recette visuelle. Chrome teste le vrai build et
conserve arbres/captures séparés. Les tests de saisie web utilisent les événements
clavier réels après focus ; un simple remplissage DOM pouvait précéder la connexion
de l'éditeur Flutter et ne constitue pas une preuve d'un défaut de l'application.
Aucune certification d'accessibilité, de TalkBack/VoiceOver ou de clavier virtuel
physique n'est revendiquée. Les résultats définitifs et configurations réellement
observées sont consignés dans le suivi TDD associé. Aucun commit ni push effectué.

## Clôture après régressions et rendu final

952 tests Flutter complets réussis (3 min 20), 49 tests ciblés réussis avec Poppins,
analyse ciblée sans diagnostic, build web release réussi et quatre configurations
Chrome finales réussies (104 s), sans exception JavaScript. Arbres et captures
finales inspectés ; résultats détaillés dans `accessibility-2026-10-26/observations.md`.
Les captures de diagnostic et du build intermédiaire ont été retirées du dossier
de rendu final. Relecture du diff et des limites après ces vérifications : aucun
défaut bloquant restant identifié dans le périmètre. `git diff --check` passe.
