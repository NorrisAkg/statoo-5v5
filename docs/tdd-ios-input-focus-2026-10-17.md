# TDD — zoom iOS au focus — 17 octobre 2026

Scénarios écrits avant le correctif. Références relues : design-system, thème, PrimaryButton, onboarding et réglages. Aucun changement de composition Flutter.

| ID | Cas | Attendu |
| --- | --- | --- |
| IOS-01 | Input sémantique Flutter texte, mot de passe, nombre et textarea | Police HTML calculée >= 16 px sur WebKit iOS avant le focus ; clavier, valeur et focus fonctionnels. |
| IOS-02 | Champs créés après navigation | Même protection sans observer ni reconstruire le DOM ; fermeture/réouverture sans perte de saisie. |
| IOS-03 | Rendu Flutter et champs extérieurs | Aucune modification des tailles Dart, des positions, transformations ou champs ordinaires. |
| IOS-04 | Accessibilité et zoom volontaire | ensureSemantics conservé ; pas de user-scalable=no, maximum-scale=1, rechargement ni remise à zéro du zoom. |
| IOS-05 | Livraison | Feuille chargée dans index.html avant le bootstrap, donc disponible avant un autofocus ; copiée par le build Flutter et le packaging. |
| IOS-06 | Régression shell PWA | Installation/aide iOS, mises à jour, cache et stockage conservés. |
| IOS-07 manuel | iPhone 13 Safari et Chrome : texte/mot de passe/nombre/multiligne, clavier fermé puis navigation | Pas de zoom automatique persistant, pas besoin de réactualiser ; saisie conservée. |
| IOS-08 manuel | 320/390/393, clair/sombre, texte 100/130/200, rotation et autonome | Cadrage, zones sûres et zoom volontaire utilisables. |

Le test ordinateur démontre la taille CSS et la saisie ; il ne simule pas le zoom automatique du clavier natif iOS. Ticket amont : https://github.com/flutter/flutter/issues/192327.

## Résultats observés

- RED : 2 échecs attendus, dont la police sémantique sous 16 px ; `ios-input-red.txt`. Pas un échec d'environnement.
- GREEN : 9/9 tests ciblés (2 focus/CSS + 7 shell), `ios-input-green.txt`.
- Régression : 61/61 tests web unitaires, `ios-input-regression.txt`.
- La matrice du shell teste 320/393, deux thèmes, texte 100/130/200 ; elle ne démontre pas la recette de tous les écrans Flutter.
- Correction dans `mobile/web/pwa-shell.css`, chargé avant le bootstrap par l'index existant. Couverture des éditeurs sémantiques input/textarea créés dynamiquement. Les champs ordinaires gardent leur taille et la valeur saisie est conservée après perte du focus.
- Limites : aucun iPhone physique ni clavier natif iOS dans cet environnement ; le test Chromium active le contenu de la requête de capacité iOS pour vérifier le comportement CSS, sans prétendre reproduire le zoom WebKit. VoiceOver et l'effet réel du focus doivent être contrôlés sur appareil.
- Aucun commit, push ou déploiement ; modifications antérieures de l'onboarding et du shell conservées.
- Build release Flutter réussi (50,5 s de compilation), `ios-input-build.txt`.
- Smoke sur le vrai build Flutter dans Chrome Windows à 390 px/DPR 3, règle iOS activée pour ce contrôle : passage de la présentation puis création de groupe, saisie « Équipe QA iPhone », perte de focus. Police sémantique observée 16 px, valeur conservée, visualViewport.scale=1. Capture `ios-input-flutter.png`, résultat `ios-input-smoke.txt`, script reproductible `ios-input-smoke.cjs`. Aucun serveur public ou donnée utilisateur modifié. Ce contrôle ne prouve pas l'ouverture du clavier natif iOS.
- Packaging universel réussi : 80 ressources, version `65fe98ff036d080d`. Le résultat inclut le shell PWA local préexistant et le correctif CSS.
- Capture examinée : champ et action principale dans la largeur de 390 px. Deux limites visuelles distinctes restent visibles : menu Application superposé au badge d'étape, label/placeholder du nom court superposés après focus. Ces observations ne permettent pas de déclarer l'écran entièrement validé ; elles sont hors du correctif du zoom et n'ont pas été modifiées.
