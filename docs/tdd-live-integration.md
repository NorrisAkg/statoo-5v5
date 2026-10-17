# Intégration de la saisie en direct — 17 octobre 2026

Référence : prototype validé `web/prototypes/live-stats`. Cible : écran Flutter commun mobile/web. Les modifications déjà présentes restent conservées sur la branche dédiée.

## Scénarios définis avant code

| ID | Cas | Résultat attendu |
|---|---|---|
| INT-01 | But avec buteur et passeur | Une transaction augmente score, buts et passe ; un événement local durable. |
| INT-02 | But sans passeur / non attribué | Score +1, aucune passe ; compteur non attribué si nécessaire. |
| INT-03 | Même buteur/passeur, joueur autre équipe, inconnu, équipe C en match | Refus sans écriture ni journal. |
| INT-04 | Tournoi | Victoires +/-1 indépendantes des buts ; pas de match individuel, compteur jamais négatif. |
| INT-05 | Jaune/rouge | Joueur requis ; score inchangé. |
| INT-06 | Annulation | Dernière action complète restaurée, y compris passe, journal durable après recréation du repository ; journal vide sans mutation. |
| INT-07 | Correction de but | Retirer anciennes attributions et appliquer nouvelles, score inchangé ; correction annulable, équipe sélectionnée inchangée. |
| INT-08 | Séance inconnue, autre groupe, inactive ou clôturée | Refus atomique ; rôles contrôlés par le service partagé avant écriture. |
| INT-09 | Erreur stockage, données de journal corrompues | Transaction annulée ; erreur affichée, aucune prétention de succès. |
| INT-10 | Synchronisation ou correction externe | Annulation/correction refusée si état différent de celui du journal ; données récentes préservées. Anciennes statistiques conservées comme base. |
| INT-11 | Saisie | Choix buteur puis « But de … / Qui lui a fait la passe ? » ; Aucun passeur, Retour au buteur, Annuler le but ; aucune écriture partielle ni passe autonome. |
| INT-12 | UI | Onglet actif explicite, joueurs et actions de son équipe ; rôle consultation et séance clôturée sans saisie ; mutations en cours bloquent doubles appuis. |
| INT-13 | Résumé | Dégradé/écussons conservés, pas de titre ni texte vide, ballon puis xN pour N>1, buteurs du bon camp. |
| INT-14 | Clôture/reprise | Récapitulatif et confirmation existants conservés ; chiffres actualisés, écriture locale immédiate et synchronisation selon circuit existant. |
| INT-15 | Régression et cadrage | Clair/sombre 320/393, texte 100/130/200 ; noms longs, dialogues défilants, cibles 48 dp ; accueil, finance et statistiques agrégées restent corrects. Clavier physique/virtuel, zones sûres et lecteur d'écran à vérifier séparément. |
| INT-16 | Revue : but → modification externe → carton → correction ancien but | Ancien journal conservé et marqué obsolète, correction refusée ; nouvelles actions restent utilisables et annulables. |
| INT-17 | Recette visuelle : coche et hauteur tactile | Coche rendue avec Remix (pas un caractère absent de la police embarquée) ; boutons de saisie/picker d'au moins 48 dp. |

Le journal est local à l'appareil et au groupe ; les agrégats de séance continuent d'utiliser la synchronisation existante. Les événements ne sont pas transmis comme historique partagé. Une restauration externe différente bloque la correction pour éviter un écrasement silencieux.

## Preuves

### RED avant code

Repository : score restant à zéro, sélections invalides acceptées par le squelette, aucune annulation durable. UI : bouton Ajouter un but absent (assertion findsOneWidget). Résumé : cadre vide encore présent. Journal corrompu `[{}]` accepté avant validation. Revue INT-16 : correction d'un ancien but encore autorisée après changement externe puis carton. INT-17 : icône Remix attendue absente (`live-touch-red.txt`). Ces échecs ont précédé les corrections correspondantes. Le premier scroll de la fixture et les attentes de libellés sémantiques Chrome incorrectes ne sont pas des preuves RED.

### Résultat automatisé

- `flutter test test/features/sessions test/features/home/latest_session_test.dart test/features/shared/lifecycle_sync_test.dart` : **166 tests réussis**, incluant le repository, les permissions membre/SG et le payload en attente de synchronisation (`live-flutter-final.txt`).
- Matrice supplémentaire du tournoi avec noms longs, buts et dialogues : 320/393 × clair/sombre × texte 100/130/200, 12 combinaisons réussies (`live-populated-matrix.txt`). Comprise dans les 166 tests, pas un total supplémentaire.
- Analyse ciblée des cinq fichiers applicatifs : aucune anomalie (`live-analysis.txt`).
- Build Flutter web release réussi (`live-build-final.txt`), packaging commun régénéré dans `web/universal-dist`.
- Chrome : `node --test web/tests/live-integration.e2e.mjs`, **1 parcours réussi** : groupe fictif, démarrage, but, correction, annulation, rechargement et reprise depuis l'accueil (`live-browser-results.txt`). Le journal persiste dans SQLite web.
- Revue dédiée : protection de la rupture d'historique corrigée et validée, 11 tests repository rejoués par le relecteur.

### Rendu observé et limites

Vu à l'écran à 393 px clair : résumé avec dégradé/écussons, buteur au ballon, onglet actif avec coche Remix, commandes de saisie et roster (`live-captures/live-goal-393.png`), puis état restauré (`live-restored-393.png`). Le prototype avait été vu en sombre ; cela ne remplace pas une recette visuelle exhaustive du nouvel écran Flutter en sombre et à grand texte. Le cadrage a été automatisé, sans déclaration de validation visuelle complète.

Appareil Android/iOS physique, clavier virtuel, SafeArea réelle, TalkBack/VoiceOver, Safari/Firefox et installation PWA non contrôlés dans ce lot. Aucun déploiement distant, commit ou push. Le contrat réseau réutilise les agrégats existants ; une vraie synchronisation multiappareils n'a pas été rejouée ici. Le journal détaillé est local à l'appareil et n'est pas un historique partagé.

Aperçu intégré local : http://127.0.0.1:19095/ (compilation Flutter réelle, données propres à cette origine). Prototype de référence conservé sur 19094. L'ancien portail sous `/portal/` reste un parcours distinct ; cette intégration cible Flutter commun mobile/web.
