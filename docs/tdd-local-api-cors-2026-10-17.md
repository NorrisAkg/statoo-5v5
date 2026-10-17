# Accès API depuis l’aperçu local — scénarios avant correction

Diagnostic réel : API /health200 ; preflight OPTIONS /groups19095400 sans Access-Control-Allow-Origin ;18085 et domaineVercel200. Donc CORS bloque le navigateur avant la création, ce n’est pas une preuve d’absence de réseau.

- API Render staging : autoriser exactement127.0.0.1:19095 et localhost:19095, conserver18085 et origines explicites.
- Render main et hors Render : ne pas ajouter ces origines automatiquement ; origine distante étrangère et autre port local restent refusés ; aucun wildcard.
- Transport web : ClientException réseau et délai dépassé donnent un message français actionnable, sans classe technique ni URI ; détails métier HTTP400/401/409/422 conservés.
- Transport natif : erreur réseau présentée également sans diagnostic technique brut.
- Conserver les champs et la préparation locale, ne pas annoncer de création réussie et ne pas créer un autre groupe sur une nouvelle tentative (régressions de l’entrée).
- Une vérification locale verte ne prouve pas le déploiement Render : refaire le preflight19095 après déploiement avant de déclarer l’aperçu connecté à l’API publique.

Références : design-system, groupe partagé, réglages, transportsHTTP web/natif.

## Résultats observés
- RED CORS :1échec attendu sur Render staging19095,3cas existants verts. Puis4tests de configuration verts (main/horsRender/origines étrangères compris).
- RED message :3échecs attendus pour ClientException web, timeout et refus socket natif ; erreur métier409 préservée.
- GREEN Flutter :34tests ciblés réussis, dont les4tests de transport et les régressions d’entrée/attribution des rôles. Revue dédiée validée.
- Build web release réussi, aperçu19095 mis à jour avec message français. La modification CORS n’est pas encore déployée sur l’API publique ; le blocage de connexion y reste attendu tant que Render n’a pas reçu la correction.
- Aucune création de groupe de test envoyée à l’API publique : seulement GET /health et preflights OPTIONS. Aucun changement de données du navigateur.
- Régression backend complète :76tests réussis ; avertissements existants httpx/Starlette et cache pytest non inscriptible, sans échec de test. Journal local-api-backend-green.txt. Aucun push effectué à ce stade.
