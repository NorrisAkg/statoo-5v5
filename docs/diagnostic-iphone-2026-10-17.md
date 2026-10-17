# Diagnostic iPhone 13 — 17 octobre 2026

## Observations

- Capture utilisateur : interface agrandie, contenu coupé à droite sur l'accueil ; toutes les pages concernées selon le signalement.
- Version publique examinée par Chrome installé, contexte mobile 390 × 844, DPR 3 : largeur innerWidth et visualViewport 390, scale 1, flutter-view 390 × 844. Aucun menu #statoo-pwa. HTML public sans feuille pwa-shell.css ni icône Apple ; les sources locales contiennent ces éléments. La présence du script app-shell.js public ne prouve donc pas la livraison du nouveau shell.
- Ce contrôle Chromium sur Windows ne reproduit pas WebKit sur un iPhone. La capture docs/iphone-public-before.png montre uniquement le contrôle public dans ce contexte.
- Piste à vérifier, pas une cause confirmée : zoom iOS après saisie. Flutter signale un cas avec sémantique activée dans https://github.com/flutter/flutter/issues/192327 ; main_web.dart active ensureSemantics. Ne pas retirer l'accessibilité ni bloquer le zoom sur cette seule corrélation.
- Aucune correction applicative ni aucun déploiement dans ce diagnostic. Modifications préexistantes conservées. Branche codex/iphone-viewport-pwa.

## Scénarios prévus avant toute correction

| Cas | Attendu |
| --- | --- |
| iPhone 13, Chrome et Safari, ouverture à zoom 100 % | Contenu cadré à 390 px, actions atteignables, pas de coupure latérale. |
| Saisie puis fermeture du clavier, changement de page | Pas d'agrandissement automatique persistant ; champ et validation atteignables. |
| Rotation puis retour portrait | Recalcul des dimensions sans découpage. |
| Zoom utilisateur et texte 100/130/200 % | Agrandissement volontaire conservé, accessibilité non désactivée. |
| Accueil, séances, joueurs, finances, réglages | Même enveloppe correcte ; noms et montants longs couverts séparément. |
| 320/390/393 px, clair/sombre, navigateur et autonome | Zones sûres et commandes visibles ; ne pas confondre tests sans overflow et contrôle visuel. |
| iOS sans beforeinstallprompt | Installation accessible via aide explicite et procédure Partager / Sur l'écran d'accueil. |
| Android avec invite, refus, erreur, application installée | Invite uniquement au clic, réessai possible, commande masquée en mode autonome. |
| Ancienne version en cache et nouvelle version | Mise à jour explicite, données locales conservées, pas de rechargement pendant une saisie sans confirmation. |

## Suite conditionnée par la reproduction

Identifier le navigateur, sa version iOS et l'effet d'un retour du zoom à 100 %. Reproduire sur WebKit/iPhone avant de choisir un correctif du cadrage. Le shell PWA local dispose déjà de tests dédiés ; sa livraison doit être distinguée d'une correction iPhone démontrée.
