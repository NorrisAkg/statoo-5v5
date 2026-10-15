# Configuration de l'API PWA par environnement

Scénarios écrits avant le code applicatif.

| ID | Scénario | Attendu |
| --- | --- | --- |
| CFG-01 | Connexion et création de groupe | Aucun champ ni rubrique d'adresse de serveur ; requêtes vers l'adresse configurée. |
| CFG-02 | Adresse absente ou vide | Origine du site utilisée automatiquement. |
| CFG-03 | Adresse HTTPS avec préfixe et slash final | Préfixe conservé, slash final normalisé. |
| CFG-04 | Adresse invalide, protocole non HTTP, identifiants, query ou fragment | Configuration refusée explicitement, aucun envoi d'identifiants. |
| CFG-05 | Portail servi par FastAPI | Configuration publique issue de STATOO_PUBLIC_API_URL, aucun secret d'environnement exposé. |
| CFG-06 | Portail statique compilé | Même configuration publique dans dist ; lecture .env.local puis .env, priorité aux variables du processus. |
| CFG-07 | Hors connexion après installation | Configuration incluse dans le shell public ; aucun .env servi ou copié. |

Les sessions existantes conservent leur serveur d'origine jusqu'à la déconnexion afin de ne jamais transférer un jeton à un autre serveur. Le nouveau serveur s'applique aux prochaines connexions.

## Résultats du 15 octobre 2026

- RED avant implémentation : présence du champ dans le test navigateur (1 au lieu de 0), trois tests web en échec et deux réponses 404 sur la configuration publique backend.
- GREEN : 30 tests unitaires web, 27 tests navigateur existants, un nouveau test navigateur couvrant connexion et création de groupe, deux nouveaux tests backend réussis.
- `npm run build:web` réussi. Contrôle du livrable compilé avec une variable de processus HTTPS comportant un préfixe : normalisation du slash et JSON public limité à `api_url` vérifiés. Nouvelle compilation avec le `.env` local : adresse vide et origine automatique vérifiées.
- Le test de renouvellement des caches a été adapté à la nouvelle version du shell ; le test hors connexion existant passe avec les nouveaux fichiers de configuration.
- Aucun test sur appareil physique supplémentaire ; les anomalies de l'audit précédent restent hors périmètre de cette modification.
