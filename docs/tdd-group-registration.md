# Création de groupe — scénarios avant implémentation

| ID | Situation | Résultat attendu |
| --- | --- | --- |
| GRP-01 | Création sans identifiant ou avec ancien identifiant envoyé par un client | Serveur attribue un identifiant aléatoire `#` + 8 chiffres ; le client ne choisit pas l'identifiant. |
| GRP-02 | Tirage avec zéros initiaux | Huit chiffres conservés, par exemple `#00000001`. |
| GRP-03 | Collision avec un identifiant existant | Nouveau tirage, aucune modification du groupe existant ; contrainte primaire garantissant l'unicité, y compris lors de créations concurrentes. |
| GRP-04 | Collisions répétées | Arrêt borné avec erreur explicite, aucune création partielle ni jeton délivré. |
| GRP-05 | Connexion et consultation après création | Identifiant retourné visible et utilisable ; `#` encodé dans les URL de requêtes ; connexion aux groupes historiques conservée. |
| GRP-06 | Liste de membres séparée par retours à la ligne, virgules ou mélange | Noms séparés et espaces de bord supprimés, espaces internes conservés. |
| GRP-07 | Virgules/lignes vides et liste uniquement vide | Entrées vides ignorées ; liste sans nom refusée avant envoi. |
| GRP-08 | Identifiant collectif | Courte description visible sous le champ, liée par aria-describedby : accès partagé de consultation des membres. |
| GRP-09 | Formulaire de création puis formulaire de connexion | Aucun identifiant à saisir pour créer ; identifiant demandé pour se connecter. |

Les identifiants des groupes existants ne sont pas renommés. Les anciennes versions clientes envoyant un identifiant à la création doivent utiliser celui retourné par le serveur.

Cas découvert avant correction mobile : GRP-10 — une requête mobile vers un groupe contenant `#` doit transmettre ce caractère dans le chemin HTTP, sans le transformer en fragment ; conserver également le préfixe d'API et les identifiants historiques. Test avec un vrai serveur HTTP local avant modification du transport.

## Preuves d'exécution

- RED : création sans identifiant refusée par l'ancien backend (422) ; champ de saisie encore présent dans le navigateur ; analyse des membres ne prenant pas en charge les virgules.
- RED mobile : chemin reçu `/api/groups/` au lieu de `/api/groups/#00000001`. Correction minimale : encoder `#` avant de construire l'URL. Le test décode le chemin reçu pour comparer sa valeur logique.
- GREEN : 42 tests backend, 29 tests navigateur et 2 tests mobiles ciblés (transport HTTP et import du format PWA). Le parcours réel crée un groupe, vérifie son identifiant affiché, puis se reconnecte avec cet identifiant.
- Les fixtures historiques backend utilisent maintenant un tirage déterministe et des chemins encodés afin de vérifier les permissions et la synchronisation avec le nouveau format.
- Pas de vérification physique Android/iOS supplémentaire ; la création native depuis un groupe local préexistant n'est pas couverte par ces tests ciblés.
