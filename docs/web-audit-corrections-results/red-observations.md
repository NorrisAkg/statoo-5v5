# Preuves RED observées avant les corrections

Exécutions des 15–16 octobre 2026. Les scénarios sont définis dans
`../tdd-web-audit-corrections.md`. Les premières traces temporaires ont disparu
au renouvellement de l'environnement ; les observations ci-dessous proviennent
des sorties réellement lues pendant la session. Les nouvelles traces sont
conservées directement dans ce dossier.

| Test | Résultat observé avant correction |
| --- | --- |
| `node web/tests/audit-fixes.test.mjs` | 7 tests, 7 échecs : absence de refus pour brouillon périmé ; mutation acceptée rejetée sur `offline` ; ancienne réponse remplaçant `Groupe` par `Périmé` ; exception `Denied` à la construction ; erreur brute JSON sur HTML ; classement Amine avant Zaki ; clôture à un joueur acceptée. Les six premiers sont également consignés dans l'audit comparatif. |
| AUD-01 navigateur | Brouillon de révision 1, valeur 150 ; serveur révision 5, valeur 900 ; envoi observé avec `base_revision: 5` et valeur 150. |
| AUD-02 navigateur | Caisse 450 saisie ; après fermeture/réouverture : 0, sans confirmation. |
| AUD-07 navigateur | Catalogue retenu en attente ; consultation attendue non disponible dans le délai du test. |
| AUD-08 navigateur | Catalogue 503 ; éditeur de séance existante absent, message de catalogue indisponible. |
| AUD-09 navigateur | Getter localStorage refusé ; exception `Storage denied`, écran `Ouverture de Statoo…` figé. |
| AUD-10 navigateur | Noms jaune/turquoise/rose sur blanc : ratios 1,53 / 2,43 / 3,53, tous sous 4,5. |
| `pytest tests/test_sport_settings.py` initial | 13 échecs : `sport_settings` absent et route de réglage 404 au lieu du contrat attendu. Les étapes suivantes de ces tests n'étaient donc pas encore atteintes. |
| Flutter import PWA + group_settings | 4 réussites, 2 échecs : réglage importé absent de meta ; valeur partagée attendue 8, obtenue 6. |
| FIX-06b Flutter, après ajout du scénario | 5 réussites, 1 échec : groupe protégé déconnecté, valeur attendue 8, obtenue 4 après modification locale. |
| FIX-06c API, après ajout du scénario | 1 échec : candidat sous le nouveau minimum retenu en 200 au lieu du refus 422. Trace `candidate-red.txt`. |
| PWA-06 activation | 2 réussites, 1 échec : l'ancien cache de cette livraison n'était pas supprimé selon le scénario de renouvellement. |

Deux erreurs du harnais navigateur ont été corrigées sans modification
applicative correspondante : bouton recherché `Annuler` alors que le libellé
réel est `Revenir à la saisie` ; mesure de toute la palette effectuée sur
l'accueil (une seule séance) au lieu de la liste complète des séances.
Ces erreurs ne constituent pas des preuves RED produit.

Les premiers refus de sandbox, téléchargements indisponibles, timeouts de
préparation et refus de revue automatique pour limite d'usage sont des incidents
d'environnement. Aucun n'est compté comme preuve RED.
