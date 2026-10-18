# Copier les accès collectifs — scénarios avant code (17 octobre 2026)

## Cadrage accepté
Réglages > Accès des membres, réservé à l’Admin du groupe partagé actif. Les anciens groupes peuvent ressaisir le mot de passe existant ; le serveur le vérifie sans le changer. Mémorisation uniquement dans FlutterSecureStorage sur cet appareil (natif protégé, web WebCrypto), pas dans SQLite, backup ou serveur en clair. Mot de passe mémorisé jamais rendu à l’écran. Copie explicite : nom et identifiant du groupe, identifiant commun courant et mot de passe, mention lecture seule.

| ID | Scénario | Résultat attendu |
|---|---|---|
| ACC01 | Admin, mot de passe existant correct | Serveur confirme par empreinte, renvoie identifiant commun seulement ; stockage local après confirmation, aucun changement du mot de passe, des sessions membres ni des données serveur. |
| ACC02 | Mauvais mot de passe, vide, trop court/long | Refus clair ; aucune nouvelle valeur mémorisée ; ancienne valeur locale intacte lors d’une nouvelle saisie refusée. |
| ACC03 | Non connecté, collectif, responsable nonAdmin, autre groupe, identité expirée | Refus serveur et absence de l’option côté UI ; aucune lecture/copie possible depuis un autre compte, groupe ou serveur. |
| ACC04 | Réouverture de l’application | Accès local retrouvé pour le même Admin/groupe/serveur, mot de passe masqué ; pas de ressaisie nécessaire. |
| ACC05 | Copier les accès | Revérification serveur du secret mémorisé, identifiant commun actuel, texte complet dans presse-papiers uniquement sur appui, confirmation après copie réussie ; aucun mot de passe personnel Admin copié. |
| ACC06 | Rotation des accès ailleurs / rôles retirés | Copie refusée, secret local obsolète effacé sur refus400/401/403 ; nouvelle saisie proposée. Nom commun modifié avec même mot de passe : copie du nouvel identifiant confirmé par serveur. |
| ACC07 | Offline, panne serveur, erreur de stockage ou presse-papiers | Erreur explicite, aucun faux succès/copie ; réseau en panne ne supprime pas le secret local ; pas de persistance avant validation ni de message technique contenant le secret. |
| ACC08 | Changement groupe/compte pendant requête, double appui, annulation | Ne pas enregistrer/copier pour le nouveau contexte ; une opération à la fois, annulation conserve les anciens accès ; champ détruit après dialogue. |
| ACC09 | Oublier / déconnexion | Effacer le secret de cet appareil ; ne pas modifier les accès distants ni les autres groupes ; déconnexion efface le secret associé. |
| ACC10 | Parité / cadrage | Même parcours Flutter mobile/web ; clair/sombre320/393, texte100/130/200 %, clavier et zones sûres, noms longs ; UI défilante, copie/erreurs accessibles ; contrôles visuels séparés des widgets sans overflow. |

Références lues : docs/design-system.md, thème/AppCard/showAppFormDialog, Réglages, Groupe partagé et financial_defaults_section. Pas d’appel de création ni de mot de passe utilisateur transmis dans les tests publics.

## Résultats observés

- RED backend : 4 tests comportementaux échouent sur 404 (endpoint absent), puis 4/4 verts après implémentation. La validation des longueurs renvoie une erreur générique sans recopier le secret soumis.
- RED Flutter : façade compilable sans comportement, puis 5 échecs attendus sur mémorisation/contrôle/contexte. Interface vide : 7 échecs attendus sur formulaire et boutons (journaux `collective-access-red.txt`, `collective-access-ui-red.txt`). Le thème réel manquant dans une fixture a ensuite été corrigé ; cet incident de fixture ne constitue pas une preuve RED.
- GREEN final : **25 tests ciblés Flutter** réussis (`collective-access-green.txt`), dont erreurs presse-papiers/stockage, oubli, déconnexion, isolation entre serveurs, refus 401/403, mot de passe changé et contexte changé pendant vérification.
- Régression complète exécutée : **732 tests Flutter**, **80 tests backend** réussis (`collective-access-regression.txt`, `collective-access-backend.txt`). Après corrections de style/icônes et ajout de trois cas d’autorisation/isolation, les 25 tests ciblés sont repassés ; la suite complète n’a pas été répétée sans motif fonctionnel supplémentaire.
- Build web finale réussie (`collective-access-build.txt`) ; analyse des trois nouveaux composants : aucun diagnostic (`collective-access-analysis.txt`).
- Chrome + API locale isolée en mémoire : vrai login Admin, mauvaise saisie refusée, bonne saisie confirmée, accès retrouvés après rechargement, copie explicitement demandée avec identifiant réel du groupe et mot de passe collectif (jamais le personnel), aucune valeur en clair retrouvée dans localStorage, rotation distante refusant la copie et demandant une nouvelle saisie ; membre connecté sans carte d’accès. Test `web/tests/collective-access.e2e.mjs`, résultat `collective-access-browser.txt`.
- Revue dédiée : aucun défaut bloquant identifié dans le périmètre ; aucun autre travail concurrent n’a été inclus volontairement dans ce changement.

## Visuel, parité et limites

- Captures Chrome **393 × 852** inspectées en clair et sombre : carte lisible, secret non rendu, dialogue défilant et erreur au bon endroit. Fichiers `collective-access-captures/form-light.png`, `form-dark.png`, `saved-light.png`, `saved-dark.png`.
- Widgets carte et dialogue contrôlés en clair/sombre, **320/393**, texte **100/130/200 %**, nom long et clavier simulé de 280 dp ; aucun débordement détecté. Cela ne remplace pas une recette de clavier natif ou d’accessibilité sur téléphone.
- Non exécuté : appareil physique Android/iOS, lecteur d’écran, zones sûres réelles, intégration presse-papiers native. Même code Flutter des deux plateformes ; stockage natif réel non testé sur appareil.
- Web : WebCrypto sur HTTPS/localhost protège la valeur persistée ; ce stockage navigateur n’offre pas l’isolation matérielle du trousseau natif et reste accessible au code autorisé de cette origine. Le serveur conserve uniquement son empreinte existante. Ni SQLite ni sauvegarde ne reçoivent ce nouveau secret.
- Hors connexion : pas de copie validée sans vérification serveur ; le secret local est conservé pour réessayer. Aucune rotation automatique ni modification des accès des membres.
- **Non déployé et non commité dans ce périmètre**. La nouvelle route nécessite le déploiement backend avant utilisation publique. Recette réalisée uniquement sur ports locaux 19111/19112, sans changement des données publiques ni des données navigateur de l’utilisateur sur 19095.
