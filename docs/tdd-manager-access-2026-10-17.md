# Accès des gestionnaires — scénarios avant code, 17 octobre 2026

| ID | Scénario | Résultat attendu |
|---|---|---|
| GES01 | Création gestionnaire | Mot de passe de 8 caractères généré par Random.secure, majuscules/minuscules/chiffres, sans champ de saisie Admin ; membre, identifiant et rôle restent obligatoires. Compte créé confirmé puis secret protégé localement. |
| GES02 | Copie | Admin uniquement ; vérification serveur du secret actuel puis texte avec groupe, identifiant personnel et mot de passe du gestionnaire choisi ; aucune copie automatique. |
| GES03 | Compte existant sans secret local | Ressaisir et vérifier le mot de passe existant, ou générer un nouveau après confirmation explicite ; annuler ne modifie rien. |
| GES04 | Nouveau mot de passe confirmé | Exactement 8 caractères, empreinte uniquement côté serveur, révocation des sessions du compte cible uniquement ; autres comptes et rôles conservés. Ne pas réinitialiser son propre compte Admin depuis cette action. |
| GES05 | Refus | Anonyme, collectif, nonAdmin, autre groupe, cible inconnue/collective, mauvais secret : refus sans modification ni fuite de mot de passe. |
| GES06 | Erreurs et conflits | Panne réseau/stockage/presse-papiers : erreur claire, aucun faux succès. Échec création ne mémorise rien ; compte créé avec stockage échoué clairement signalé sans répétition de création. Secret périmé purgé sur refus lors de copie. |
| GES07 | Isolation et reprise | Cache par serveur/groupe/Admin/cible, après relancement ; changer de contexte pendant requête empêche la mémorisation/copie. Logout efface les secrets des gestionnaires du contexte Admin seulement. |
| GES08 | UI et régressions | Même Flutter web/mobile, accès par compte dans Comptes et rôles et parcours initial ; titre/identifiant non ambigus, secret masqué, double appui bloqué. Clair/sombre 320/393, texte100/130/200 %, dialogue défilant/clavier simulé. Accès collectif et choix de rôles inchangés. Recette physique distincte. |

Références lues : design-system, AppTheme, AppCard, showAppFormDialog, Groupe partagé et carte Accès des membres.

- GES09 (découvert en recette Chrome, avant correction) : après copie depuis une fiche modale de gestionnaire, la confirmation doit être visible dans cette fiche. Un SnackBar de l’écran situé derrière la modale ne suffit pas. Ajouter le test widget puis observer son échec avant correction.

## Réalisation et preuves — finalisation du 18 octobre

- RED serveur : **9 échecs** attendus (nouveaux endpoints absents, 404), puis **13 tests ciblés** gestionnaires + collectifs verts. Journaux `manager-access-backend-red.txt` et `manager-access-backend-green.txt`.
- RED Flutter : générateur vide, absence de namespace/route individuels et remplacement sans effet ; 3 échecs attendus (`manager-access-red.txt`). Le formulaire existant possède encore un champ mot de passe : échec attendu du scénario modifié (`manager-access-ui-red.txt`). Confirmation GES09 absente de la modale : échec attendu (`manager-access-copy-feedback-red.txt`). Les erreurs de compilation et la collision d’édition du formulaire ont été corrigées sans être comptées comme RED.
- GREEN final : **69 tests ciblés Flutter** réussis (`manager-access-green.txt`), incluant génération 8 caractères, accès isolés, confirmation/annulation de remplacement, erreurs/réessai/double appui et cadrage carte/formulaires. Les anciens tests de validation d’un mot de passe saisi ont été adaptés à la génération ; les validations d’identifiant et les erreurs restent couvertes.
- Régression complète : **89 backend** réussis (`manager-access-backend-regression.txt`), **812 Flutter** réussis (`manager-access-flutter-regression.txt`). La correction visuelle GES09 et les 12 variantes de cadrage de la fiche ont ensuite été vérifiées dans les 69 tests ciblés ; pas de répétition de la suite complète après ce changement local.
- Build Flutter web finale réussie (`manager-access-build.txt`). Analyse statique : aucune erreur ni avertissement, deux informations de style préexistantes dans SharedGroupScreen (`manager-access-analysis.txt`).
- Chrome, application Flutter réelle et API SQLite en mémoire sur ports19121/19122 : création d’un gestionnaire SG depuis l’interface, mot de passe généré vérifié à 8 caractères, copie du bon identifiant/groupe/mot de passe, absence de mot de passe en clair dans localStorage, connexion effective du gestionnaire dans un second contexte navigateur, reprise de la copie après rechargement, annulation sans remplacement, remplacement confirmé et copie du nouveau secret. Réussite : `web/tests/manager-access.e2e.mjs` et `manager-access-browser.txt`. Le mot de passe Admin n’est jamais inclus dans le texte copié.
- Revue dédiée finale : aucun défaut bloquant identifié sur autorisations, révocation ciblée, isolation des secrets, ou distinction entre compte créé et cache/actualisation échoués.

## Visuel et limites

- Captures inspectées à **393 × 852** : création claire sans saisie de mot de passe, fiche claire avec confirmation de copie visible, confirmation de remplacement sombre et fiche sombre (`manager-access-captures/`). Secret jamais dessiné dans la fiche.
- Widgets carte + dialogue de vérification et dialogue de création : clair/sombre, **320/393**, texte **100/130/200 %**, clavier simulé et identifiant long ; aucun débordement détecté. Validation automatique distincte de la recette visuelle Chrome.
- Non exécuté : téléphone physique, stockage natif réel, presse-papiers natif, lecteur d’écran et zones sûres physiques. Même code Flutter sur mobile/web ; stockage web via WebCrypto sur localhost/HTTPS.
- Les nouveaux mots de passe ne sont pas ajoutés aux snapshots, à SQLite ni aux sauvegardes. Côté serveur : empreinte uniquement. Le secret reste propre à l’appareil, au serveur, au groupe, à l’Admin et au compte ciblé ; la déconnexion nettoie ce contexte sans supprimer les accès d’autres serveurs.
- Recette réalisée avant commit, push et déploiement de ce lot. Les nouveaux endpoints devront être déployés avec l’application pour la mise en ligne. Aucune donnée publique ni stockage navigateur de l’utilisateur n’a été modifié pendant la recette.
