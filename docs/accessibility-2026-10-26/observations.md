# Contrôle du vrai build Flutter web — F08

Chrome headless, contextes isolés, données locales synthétiques (Alice, Bob et
Jean-Pierre au nom particulièrement long). Build release de `main_web.dart`,
Poppins embarquée, aucune connexion à un groupe utilisateur ou API métier.

| Vue | Texte | Thème / format | Composition | Nom long | Arbre accessible |
|---|---|---|---|---|---|
| 320×568 | 100 % | clair / classique | [Capture](composition-320-1-light.png) | [Capture](long-name-320-1-light.png) | [Arbre](long-name-semantics-320-1-light.txt) |
| 393×852 | 100 % | sombre / tournoi | [Capture](composition-393-1-dark.png) | [Capture](long-name-393-1-dark.png) | [Arbre](long-name-semantics-393-1-dark.txt) |
| 320×568 | 200 % | sombre / tournoi | [Capture](composition-320-2-dark.png) | [Capture](long-name-320-2-dark.png) | [Arbre](long-name-semantics-320-2-dark.txt) |
| 393×852 | 200 % | clair / classique | [Capture](composition-393-2-light.png) | [Capture](long-name-393-2-light.png) | [Arbre](long-name-semantics-393-2-light.txt) |

## Observé et automatisé dans Chrome

- Effectif initial : commandes de retrait nommées individuellement. Leur activation
  sur le bon joueur est couverte par le test widget ; le scénario Chrome ajoute
  les trois membres et inspecte les commandes, sans supprimer l'effectif de ce test.
- Nouvelle séance et Présent activés au clavier (Entrée), affectation A puis C en
  tournoi, recherche réellement saisie au clavier et filtrage vérifié, effacement,
  retrait de composition, nouvelle sélection et affectation B du nom long.
- Champ de recherche unique, nom accessible ne contenant aucun nom de joueur,
  conservé à la saisie ; les libellés A/B/C et Retirer contiennent le nom complet.
- Rendu effectivement inspecté : dispositions clair/sombre, bandeau et commandes
  défilants quand nécessaire, label complet à texte 200 %, nom long conservé sur
  plusieurs lignes, commandes d'équipe et retrait visibles dans les captures.
- Aucune exception JavaScript `pageerror` dans les quatre contextes. Le contrôle
  du rôle lecture seule et des retours spécifiques de création/effectif est widget,
  pas une validation Chrome avec connexion partagée réelle.

## Limites

Ces vues sont défilées : elles ne prétendent pas afficher tout le parcours en une
seule image. L'état sélectionné natif est vérifié dans les tests sémantiques
Flutter ; les captures montrent l'affectation et le symbole de sélection.
Texte 130 % et ouverture/fermeture du clavier avec focus sont couverts dans la
matrice widget, pas sur un clavier virtuel de téléphone. Aucun TalkBack,
VoiceOver, Safari/iOS physique, Android physique ni certification WCAG revendiqué.

Exécution finale : [log Chrome](../accessible-commands-browser-2026-10-26.txt).
