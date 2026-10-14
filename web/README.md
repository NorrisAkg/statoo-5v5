# Portail de consultation

HTML/CSS et modules JavaScript natifs. Aucun framework ni build requis.

```powershell
python -m http.server 8080 --directory web
node --test web/tests/summary.test.mjs
```

Depuis la racine du dépôt. Ouvrir `http://localhost:8080`.

Un hébergeur statique peut servir le contenu de ce dossier. Renseigner son origine dans `CORS_ORIGINS` du backend. Le portail ne contient aucun secret serveur. Le jeton utilisateur est stocké dans `sessionStorage` et supprimé à la déconnexion.

La consultation présente les séances publiées, le classement et les finances de tout le groupe. Les versions concurrentes ne remplacent pas les données publiées avant arbitrage. La première version ne gère pas la saisie ni la consultation hors ligne.
