# Refonte du Point financier — scénarios avant code

Références examinées : `statoo-captures/08-seance-detail-s9.jpg`, `finances_screen.dart`, `session_detail_screen.dart`, thème Poppins clair/sombre, AppCard et PrimaryButton. Périmètre : présentation de Point financier, sans changement des règles comptables, du stockage ou du contrat partagé.

Direction : en-tête de page cohérent avec Finances, contexte de séance dans une AppCard, membres dans des cartes avec champs nommés, sections espacées, montants formatés en français, actions Remix, récapitulatif et validation visuellement distincts. À petite largeur ou texte agrandi, champs empilés et contenu défilant ; clavier pris en compte. Les dialogues métier conservent leurs contrats.

| ID | Scénario | Attendu |
|---|---|---|
| PF01 | Ouverture, clair et sombre | Contexte daté en français, cotisation, membres sur cartes du thème ; bouton principal partagé. |
| PF02 | Cotisation/pénalité à saisir | Labels visibles, unité F, montant indicatif distinct de la valeur ; saisie numérique conservée. |
| PF03 | 320/393 dp, texte 100/130/200 %, clair/sombre | Aucun débordement, membres et champs atteignables au défilement, titres/montants lisibles. |
| PF04 | Nom long, montant à 12 chiffres | Retour à la ligne du nom ; montant non perdu ; totaux dans la largeur. |
| PF05 | Clavier 300 dp, saisie puis changement d’onglet | Champ atteignable, clavier non superposé au formulaire, saisie conservée au retour. |
| PF06 | Recherche avec/sans résultat | Membre filtré, absence de résultat explicite, effacement rétablit la liste sans perdre les montants. |
| PF07 | Participants et absents | Sections conservées ; tous les membres préparés restent cotisables. |
| PF08 | Onglet Dépenses vide/rempli, dons vides/remplis | État vide explicite ; ajout puis retrait modifie le total, annuler le dialogue ne modifie rien. |
| PF09 | Lecture seule | Contexte et montants visibles, champs désactivés, aucune action de mutation/validation ; consultation explicite. |
| PF10 | Séance annulée | Champs/mouvements verrouillés, cotisations dues expliquées, aucun mouvement de caisse. |
| PF11 | Modification de cotisation, pénalité due/motif | Dialogues existants accessibles, valeurs reprises et total réactif. |
| PF12 | Saisie modifiée puis retour app/système | Confirmation d’abandon, continuer préserve la saisie ; aucun enregistrement implicite. Tests UX02 existants. |
| PF13 | Validation puis confirmation/annulation | Récapitulatif exact ; confirmer enregistre une fois, revenir préserve le formulaire ; baseline nettoyée après succès. |
| PF14 | Sauvegarde échoue ou en cours | Feedback existant, saisie préservée, validation désactivée pendant traitement. |
| PF15 | Chargement/erreur de préparation | Progression ou erreur lisible ; aucune validation avant disponibilité des données. |
| PF16 | Groupe actif changé / droit retiré | Garde de groupe et de droits conservée, pas d’écriture dans un autre groupe. Régressions métier existantes à conserver. |
| PF17 | Défauts réellement vus sur téléphone à 200 % (capture 118) | Onglet Encaissements non tronqué grâce à une barre défilante ; récapitulatif dans le contenu défilant, pied limité à la validation (moins de 180 dp dans la fixture) ; champs atteignables. Scénario ajouté avant correction de ce nouveau cas. |

## Preuves d’exécution

Les assertions de composants vérifient le contrat visuel choisi ; elles ne remplacent pas l’inspection du rendu. Contrôle physique/lecteur d’écran à distinguer des tests widget.

- RED avant code : `tdd-point-financier-red.log` puis `tdd-point-financier-red-2.log`. Absence de cartes/bouton partagés et de labels visibles, recherche sans résultat sans feedback, absence d’état vide des dépenses, resize désactivé au clavier. Les échecs des variantes qui recherchaient un élément absent et les erreurs de montage ne constituent pas une preuve indépendante de débordement.
- GREEN final : **27 tests ciblés** (`tdd-point-financier-green-200-2.log`), dont 12 combinaisons de largeur/texte/thème, recherche et conservation de saisie, dépenses ajoutées/retirées, consultation, annulation, clavier simulé, modification de tarif, confirmation annulée, sauvegarde refusée, grand texte et cinq régressions UX02.
- Suite complète finale exécutée : **367 tests réussis** (`tdd-point-financier-regressions-200.log`). Les traces précédentes à 364 puis 366 correspondent aux étapes antérieures, pas au résultat final.
- Analyse ciblée sans erreur ni warning ; deux informations de style préexistantes dans l’écran et deux de cascade dans les tests. `git diff --check` réussi.
- Une première exécution GREEN a révélé une locale française non initialisée dans la fixture, corrigée comme dans le bootstrap de l’application. Le viewport de test est désormais mobile et le défilement cible la ListView du formulaire. Ces ajustements de montage ne sont pas des défauts produit.
- APK isolé `com.kysolutions.statoo.qa` compilé et mis à jour avec succès, sans effacement des données ni remplacement de Statoo. Les premières tentatives physiques ont été interrompues par le verrouillage Xiaomi et une autre application ; après déverrouillage, les contrôles ci-dessous ont été acquis. La capture hors QA est exclue du dépôt et ne constitue aucune preuve du rendu.
- Les aperçus Flutter exploratoires clair/sombre ont servi à examiner composition, couleurs et espacements. Ils ont été écartés des livrables car le moteur de test remplace la police du bouton par des glyphes de test. Aucun changement du composant partagé n’a été effectué pour masquer cet artefact.

## Réalisation

AppCard et palette du thème pour le contexte et les membres, avatars existants, champs remplis arrondis avec labels permanents, date/montants français, bouton PrimaryButton partagé. Les champs passent en colonne à petite largeur ou grand texte. Le contexte est défilant ; le clavier redimensionne le formulaire et masque temporairement le pied de validation. Recherche vide et dépenses vides disposent d’un message explicite. Calculs, commandes des dialogues, stockage et garde de groupe restent inchangés.

## Couverture physique et limites

### Contrôles physiques acquis

Android 1080 × 2400, thème sombre. Vue en consultation qa-depart avec champs désactivés et absence de mutation (capture 110), dépenses vides (111), vue éditable du groupe QA Alpha (112/113), vrai clavier numérique avec champ au-dessus du clavier et pied masqué (117). Aucun montant saisi ni point validé pendant ces contrôles. Les cartes, avatars et typographies sont visibles dans l’APK, contrairement aux artefacts de police des aperçus de test.

Les tentatives 114–116 ont eu lieu sur un autre écran après une navigation inattendue et sont exclues des preuves financières. La capture 118 a ensuite confirmé la troncature de l’onglet et le pied disproportionné à 200 % ; PF17 a été écrit et mis en échec avant correction. Les onglets sont désormais défilants à grand texte et les totaux remontent dans la carte de contexte défilante ; seul le bouton reste fixe. La première sortie UIAutomator après mise à jour était périmée (`null root node`) : elle n’est pas utilisée comme preuve ; les nouveaux scripts refusent désormais ce cas. La taille de texte initiale de 0,9 est restaurée par finally.

**Second APK vérifié à 200 %** : [onglet complet et totaux défilants](essais-appareil-2026-10-14/captures/120-point-financier-200-corrige.png), [champs empilés et atteignables](essais-appareil-2026-10-14/captures/121-point-financier-200-champs-corriges.png). Le bouton reste fixe, le formulaire dispose de davantage de hauteur. Le facteur 0,9 est restauré. PF17 est GREEN dans `tdd-point-financier-green-200-2.log` après RED dans `tdd-point-financier-red-200.log`. L’attente de frame après défilement a été ajoutée aux tests ; les variantes ouvrent réellement Dépenses, y compris quand il faut faire défiler l’onglet.

### Vérifications restantes

PF01–05 : thème clair et petites largeurs vérifiés automatiquement, à revoir physiquement ; cibles et TalkBack restent à contrôler. Sombre, clavier Android et 200 % ont été vus sur ce téléphone ; cela ne certifie pas l’accessibilité. PF07 : section Participants vue sur appareil, fixture automatique avec une absente ; combinaison des deux sections non rejouée physiquement. PF08 : dépense testée en ajout/retrait ; dons et annulation de leurs dialogues à contrôler manuellement. PF09 : consultation testée par provider et vue physiquement, matrice réelle des rôles restante. PF10 : désactivation testée, validation complète d’un point annulé conservée dans les tests de domaine. PF11 : tarif testé, pénalité due et motif à revoir en UI. PF14 : refus testé, sauvegarde lente/double appui à compléter. PF15 : états de chargement/erreur inchangés, non rejoués sur appareil. PF16 : gardes conservées, changement de groupe/retrait de droits pendant saisie non exécutés dans cette série. TalkBack parlé reste à tester.

La dernière tentative de capture normale et de contrôle du téléphone a été empêchée par une défaillance de l’examen automatique d’autorisation (quota d’usage épuisé). La commande n’a pas été exécutée ; il ne s’agit pas d’un jugement de dangerosité. Les captures 120/121 et la restauration du texte avaient déjà été acquises auparavant. Aucune capture 123 n’est annoncée disponible.
