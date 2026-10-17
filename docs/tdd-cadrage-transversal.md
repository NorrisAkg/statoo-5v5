# Reprise des contrôles de cadrage

Scénarios écrits avant toute correction applicative de ce lot. Références : `design-system.md`, `verification-coherence-design-2026-10-15.md`, Finances, Réglages et feuilles joueur existantes.

| ID | Conditions | Attendu |
|---|---|---|
| CAD01 | Finances, 320/393 dp, 100/130/200 %, clair/sombre, nom long, 12 chiffres | Titre Caisse et montants dans la largeur ; tableau ou détail accessible ; aucune exception de layout. |
| CAD02 | Paramètres financiers dans leur carte, mêmes variantes, montant maximal 1 000 000 000 000 F | Titres, unité, montant et action visibles ; aucune collision de ListTile. |
| CAD03 | Trois slides d’onboarding, 320 × 640 et 393 × 852, mêmes textes/thèmes | Titres et explications accessibles par défilement si nécessaire ; Suivant/Commencer atteignables ; navigation inchangée. |
| CAD04 | Modifier joueur, mêmes variantes, clavier 0/300 dp | Titre et fermeture dans la largeur, champs et validation atteignables ; saisie/annulation et permissions conservées. |
| CAD05 | Rejeu existant Point financier, détail séance, arbitrage et accueil | Tests de non-régression toujours réussis ; aucun plafonnement du texte ajouté. |
| CAD06 | Téléphone QA disponible | Vérifier écrans accessibles à 200 %, garder captures et restaurer facteur initial ; ne pas modifier les groupes de l’application réelle. |
| CAD03b | Nouveau cas constaté : illustration fictive déborde à 320 dp/200 % | Employer une illustration décorative simplifiée à grand texte ; conserver intégralement les explications et leur taille, sans plafonnement. Trois étapes et commandes inchangées. |
| CAD07 | Nouveau défaut vu sur téléphone, capture 130 : Attendu et Cotisations coupés au milieu des mots à 200 % | À grand texte, remplacer les trois colonnes denses par des lignes nommées Payé/Attendu/Écart sous le nom ; montants complets en F, détail membre toujours ouvrable. Conserver la table compacte à texte normal. Scénario écrit avant cette correction. |

Les erreurs de fixture sont séparées des débordements réels. Les contrôles automatiques ne certifient ni la qualité esthétique, ni TalkBack, ni l’ensemble des écrans physiques. Tout défaut nouveau reçoit son scénario avant code.

## Exécution après déblocage

- Flutter et ADB à nouveau autorisés ; téléphone `7522b268` détecté.
- RED : `tdd-cadrage-red-2.log`. À 320 dp, texte 200 %, débordement horizontal Finances de 39 px ; paramètres financiers : assertion ListTile « Trailing widget consumes the entire tile width ». À 130 %, titre de feuille joueur débordant de 22 px et texte d’onboarding de 1,6 px en hauteur. Ces valeurs viennent des fixtures automatisées, pas d’une mesure du téléphone.
- Le premier montage utilisait `pumpAndSettle` sur les illustrations à animation continue : timeout de fixture, exclu des défauts produit. La matrice utilise des frames bornées pour l’onboarding. La cascade d’erreurs de layout après l’assertion ListTile a motivé l’interruption du run RED ; elle n’est pas comptée comme des défauts supplémentaires.
- Corrections : titre Caisse flexible ; montant des paramètres sous le sous-titre, formaté en français, chevron séparé ; titre de feuille joueur flexible ; explications d’onboarding défilantes. À grand texte, une icône décorative remplace l’illustration fictive trop dense, sans plafonner le texte explicatif ni retirer d’étape.
- **48 variantes GREEN** (`tdd-cadrage-green-2.log`) ; tableau et détail membre réellement parcourus, et bouton de la feuille atteint sous clavier dans le complément (`tdd-cadrage-green-final.log`). Les tailles sont 320 × 640 et 393 × 852 ; textes 100/130/200 % ; thèmes clair/sombre ; trois slides d’onboarding ; clavier simulé de 300 dp pour la feuille.
- **415 tests Flutter complets réussis** (`tdd-cadrage-regressions.log`), puis complément ciblé. Analyse des fichiers sans erreur ni warning ; neuf informations de style préexistantes, et ordre des imports du nouveau test corrigé. `git diff --check` réussi.
- APK QA recompilé et installé par mise à jour sans effacement des données. L’accès à Finances QA avant mise à jour a été repéré, mais le téléphone est repassé dans WhatsApp lors de la reprise finale. Les interactions ont été arrêtées par le garde-fou ; maintien de Statoo QA au premier plan demandé. Aucun montant/score/réglage métier n’a été saisi pour ces essais. Facteur de texte relu à 0,9, non changé pendant cette reprise.

## Limites

## Recette physique finale acquise

Après déverrouillage, le script borné à Statoo QA a temporairement maintenu l’écran allumé en USB, puis restauré les deux réglages dans finally. Résultat et relecture finale : **texte 0,9 ; maintien allumé USB 0**. Aucun champ saisi, montant/score enregistré ni donnée métier modifiée ; aucun appui sur la validation. La fermeture finale de la feuille après la capture 136 n’est pas confirmée : le garde-fou a interrompu le retour faute d’activité QA visible. Cela ne remet pas en cause la restauration des deux réglages, relus ensuite.

- **Finances** : [vue générale à 200 %](essais-appareil-2026-10-14/captures/132-finances-final-200-haut.png) et [soldes lisibles](essais-appareil-2026-10-14/captures/133-finances-final-200-soldes.png). Le contrôle initial [130](essais-appareil-2026-10-14/captures/130-finances-cadrage-200.png) avait révélé les mots coupés dans la table, malgré l’absence d’exception RenderFlex. CAD07 a ensuite été écrit, mis en échec (`tdd-cadrage-red-table.log`) puis corrigé. À grand texte, les trois soldes sont nommés et empilés, avec montants complets en F ; taille normale conserve la table. L’intitulé long d’AppBar reste abrégé par le comportement natif ; ne pas confondre cela avec un titre intégralement affiché.
- **Réglages financiers** : [capture 134](essais-appareil-2026-10-14/captures/134-reglages-final-200.png). Titres sur plusieurs lignes, montants sous l’aide et chevrons conservés. Contrôle physique avec valeurs 100 F/0 F ; les valeurs maximales restent une preuve automatisée.
- **Modifier le joueur** : [capture 136 sans notification](essais-appareil-2026-10-14/captures/136-joueur-final-200-sans-notification.png). Titre complet sur deux lignes, fermeture et validation visibles. La capture 135 est exclue du dépôt car une notification masquait le titre ; elle n’est pas un livrable. Le clavier a été vu pendant cette tentative, mais la preuve partageable 136 montre la feuille sans clavier.
- **Résultats finaux** : 50 tests ciblés (`tdd-cadrage-table-green.log`) et **415 tests complets réussis après CAD07** (`tdd-cadrage-regressions-finales.log`). Dernière analyse sans erreur ni warning ; six informations de style préexistantes dans Finances, aucun diagnostic du nouveau test.

### Limites finales

Les trois surfaces corrigées accessibles ont été vues sur ce téléphone, en sombre à 200 %. Onboarding : trois étapes vérifiées dans la matrice automatisée, sans réinitialisation du téléphone ; recette physique restante. Les deux écarts de style VC04/VC05 restent ouverts. Les états, rôles, thèmes et appareils non parcourus dans la matrice globale ne deviennent pas validés par ces nouvelles preuves.

La nouvelle version doit encore être observée physiquement sur les écrans corrigés ; TalkBack et toutes les combinaisons des 16 écrans restent distincts de cette matrice de quatre surfaces. Les deux écarts de style VC04/VC05 ne sont pas modifiés par ce lot de cadrage. Les documents de cohérence conservent ces réserves ; aucun succès global n’est déduit du seul total de tests.
