# Connexion de la PWA à l'API en ligne — 15 octobre 2026

Scénarios avant modification de configuration :

- API-ONLINE-01 : l'URL publique répond à GET /health sans création de données.
- API-ONLINE-02 : l'API accepte le contrat de création automatique et la référence de reprise.
- API-ONLINE-03 : le précontrôle CORS autorise http://127.0.0.1:18085.
- API-ONLINE-04 : le build publie uniquement STATOO_PUBLIC_API_URL dans config.json ; aucun secret .env copié.

Constats : https://statoo-api.onrender.com/health répond 200. Le schéma Registration en ligne exige encore group_id et ne connaît pas operation_id. Le précontrôle depuis l'origine locale répond 400, sans Access-Control-Allow-Origin. Il faut mettre à jour le backend hébergé et sa configuration CORS avant de tester les nouvelles créations/reprises depuis le portail local.

La variable publique est préparée dans le .env local. L'API en ligne n'a reçu que des lectures et un précontrôle OPTIONS, aucune donnée de test n'a été créée. Les sessions déjà ouvertes conservent leur serveur initial jusqu'à déconnexion. Aucun déploiement distant effectué.
