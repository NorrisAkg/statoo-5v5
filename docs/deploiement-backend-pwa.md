# Déploiement du backend pour tester la PWA

## Scénarios de validation écrits avant préparation

- DEP-01 : le schéma permet une création sans group_id et accepte operation_id.
- DEP-02 : les précontrôles POST avec Content-Type et Authorization sont acceptés depuis http://127.0.0.1:18085 et http://localhost:18085 ; une origine étrangère reste refusée.
- DEP-03 : la santé répond 200, sans connexion à un compte ni création de données de test.
- DEP-04 : le paquet ne contient ni .env, ni base de données, ni dépendance locale ; le schéma existant est conservé et la nouvelle table registration_operations est ajoutée au démarrage.
- DEP-05 : le portail compilé indique uniquement l'adresse publique https://statoo-api.onrender.com.
- DEP-06 : un déploiement Render de staging autorise automatiquement les deux origines locales, même sans CORS_ORIGINS ; main et un serveur hors Render ne les ajoutent pas. Les origines déjà configurées sont conservées et une origine étrangère reste refusée.

## État et périmètre

L'API actuelle répond mais utilise l'ancien contrat de création et refuse l'origine locale. La préparation met à disposition les sources actuelles, les paramètres Render et un contrôle de réception sans écriture distante. Aucun déploiement ni changement de secret distant n'est effectué.

Sources : backend/app/main.py et backend/app/models.py. Le backend inclut la génération d'identifiants uniques, la reprise de création par operation_id, la configuration publique de la PWA et le verrou compatible avec les workers FastAPI.

## Paramètres Render

Service existant : https://statoo-api.onrender.com. Conserver le service et la base existants.

- Root Directory : backend
- Build Command : pip install -r requirements.txt
- Start Command : uvicorn app.main:app --host 0.0.0.0 --port $PORT
- Health Check : /health
- DATABASE_URL : conserver la valeur existante.
- DATABASE_URL_UNPOOLED : conserver la valeur existante si configurée, pour la création du schéma.
- CORS_ORIGINS : ajouter `http://127.0.0.1:18085,http://localhost:18085` à la liste actuelle, sans supprimer les origines déjà autorisées et sans espaces autour des virgules.
- Sur Render, la branche staging ajoute désormais automatiquement ces deux origines locales ; les autres branches conservent uniquement CORS_ORIGINS. La détection utilise [RENDER_GIT_BRANCH, variable officielle Render](https://render.com/docs/environment-variables).
- STATOO_PUBLIC_API_URL : `https://statoo-api.onrender.com` (adresse publique, aucun secret).

Ne jamais publier le .env local. Render doit utiliser ses propres variables ; la PWA reçoit uniquement api_url.

## Publication et réception

Publier la révision contenant les sources préparées sur la branche suivie par le service Render, puis lancer son déploiement. La branche réellement suivie doit être vérifiée dans Render avant toute publication ; elle ne peut pas être déduite de la branche locale.

Le démarrage utilise create_all : ajout de registration_operations sans suppression ni renommage des tables existantes. Vérifier les sauvegardes habituelles de la base avant déploiement. Les anciens identifiants de groupe restent utilisables.

Depuis la racine du dépôt, contrôler ensuite :

```powershell
backend/.venv/Scripts/python.exe scripts/check-online-api.py
```

Ce contrôle ne crée aucun groupe. Il vérifie le contrat, la santé et CORS. Pour tester la PWA locale, redémarrer son serveur afin de relire le .env, appliquer la mise à jour du shell et se déconnecter d'une éventuelle session locale avant de rejoindre/créer un groupe en ligne. Les données créées ensuite seront réellement enregistrées dans la base hébergée.

## Accès de déploiement

Aucune clé Render disponible dans l'environnement de cette session. La mise en ligne nécessite l'accès au service Render ou la publication sur sa branche de déploiement confirmée. Cette préparation n'a poussé aucun commit et n'a modifié aucun groupe distant.

## Livrable et vérifications

Paquet local : `build/statoo-backend-release-2026-10-15.zip`. Il contient le backend, ses tests, render.yaml, ce guide et le portail statique public, sans .env, base locale ou dépendances installées. Intégrité ZIP et liste des fichiers vérifiées.

Le test `backend/tests/test_deployment_readiness.py` passe : santé, contrat récent, deux origines locales autorisées et origine étrangère refusée. `npm run build:web` passe avec 38 tests ; son config.json contient uniquement l'adresse publique attendue. Les 44 autres tests backend ont été exécutés avec succès lors de la correction précédente ; aucun code applicatif backend n'a été changé pour cette préparation.

Publication sur staging autorisée par l'utilisateur. Le correctif CORS spécifique à Render/staging a été ajouté après scénario et preuve RED, puis validé par une revue dédiée. Avant commit : build complet réussi avec 48 tests backend et 38 tests web ; deux tests mobiles ciblés réussis. Les modifications mobiles concurrentes sans rapport avec la PWA sont exclues du commit. Aucun .env, capture d'audit ou paquet de build n'est publié.
