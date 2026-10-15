# Statoo — monorepo

Application de football entre amis avec suivi sportif et financier. Le dépôt contient trois composants :

| Dossier | Contenu |
| --- | --- |
| `mobile/` | Application Flutter Android/iOS, SQLite et saisie hors ligne |
| `backend/` | API Python FastAPI, rôles, synchronisation et arbitrage |
| `web/` | PWA en français, consultation et gestion par rôle, HTML/CSS/JavaScript |
| `docs/` | Documentation commune et références historiques |

La branche de travail est `codex/finances-et-groupe-partage`. Le mode local reste disponible ; un groupe partagé utilise le backend comme source des versions publiées.

## Mobile

Depuis la racine :

```powershell
cd mobile
flutter pub get
dart run build_runner build
flutter test
flutter run --dart-define=STATOO_API=https://votre-api.example
```

La compilation Android se lance aussi depuis `mobile/` : `flutter build apk --release`. La signature reste configurée dans `mobile/android/key.properties`, ignoré par Git. L’absence de signature de production doit être corrigée avant distribution.

## Backend

### Neon et lancement depuis la racine

`neon deploy` applique `neon.ts` au projet lié dans `.neon` et écrit les secrets
dans `.env.local` (ou `.env` si ce fichier existe). Le backend charge ces fichiers
automatiquement, sans remplacer les variables définies par l'hébergeur.
`DATABASE_URL` sert aux requêtes ; `DATABASE_URL_UNPOOLED` sert à la création
initiale du schéma. Les secrets restent côté serveur et sont ignorés par Git.

Après installation des dépendances Python ci-dessous et `npm install` :

```powershell
npm run build
npm start
```

Le build compile l'API, exécute les tests backend et portail, puis copie le portail
dans `web/dist`. Il ne compile pas l'application mobile Flutter.
Le serveur expose l'API sur `http://127.0.0.1:8000` et le portail sur
`http://127.0.0.1:8000/portal/`. Utiliser cette même URL d'API dans le portail.
`PYTHON` permet de choisir l'interpréteur et `PORT` le port.
Le test distant `backend/.venv/Scripts/python.exe scripts/neon_smoke.py` vérifie
création, persistance PostgreSQL, connexion, lecture et révocation d'accès ;
il nettoie uniquement les données de son propre groupe de test.

Python 3.12 ou supérieur :

```powershell
cd backend
python -m venv .venv
.venv/Scripts/python.exe -m pip install -r requirements-dev.txt
.venv/Scripts/python.exe -m uvicorn app.main:app --reload
.venv/Scripts/python.exe -m pytest
```

Par défaut, SQLite est utilisé uniquement pour le développement. Pour Neon, renseigner `DATABASE_URL` avec l’URL PostgreSQL fournie par Neon et `sslmode=require`. Ne jamais placer cette URL dans le mobile ou le web. `CORS_ORIGINS` contient les origines du portail séparées par des virgules.

Le fichier `render.yaml` décrit le service backend ; il ne déclenche aucun déploiement. Le backend refuse de démarrer sur Render sans base distante configurée.

## Web

```powershell
python -m http.server 8080 --directory web
npm run test:web
```

Ouvrir `http://localhost:8080` ou `/portal/` sur l'API. Les membres utilisent l'accès collectif ; les responsables disposent des actions de leur rôle. Installation, brouillons hors ligne et tests navigateur sont décrits dans [le guide web](web/README.md).

## Documentation

- [Groupe partagé, finances et synchronisation](docs/shared-group-and-finance.md)
- [Backend](backend/README.md)
- [Mobile](mobile/README.md)
- [Web](web/README.md)
- [Architecture historique Flutter](docs/architecture.md)
- [Règles sportives](docs/business-rules.md)
- [Sauvegardes](docs/backup.md)
- [Tests et livraison](docs/testing-and-release.md)

Les anciens documents citent `lib/`, `test/`, `android/` et `ios/` relativement au projet Flutter : leurs chemins sont désormais sous `mobile/`. Les décisions de cette branche concernant les groupes partagés complètent ces documents.
