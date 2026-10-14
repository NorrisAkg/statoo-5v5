# Statoo — monorepo

Application de football entre amis avec suivi sportif et financier. Le dépôt contient trois composants :

| Dossier | Contenu |
| --- | --- |
| `mobile/` | Application Flutter Android/iOS, SQLite et saisie hors ligne |
| `backend/` | API Python FastAPI, rôles, synchronisation et arbitrage |
| `web/` | Portail de consultation en français, HTML/CSS/JavaScript |
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
node --test web/tests/summary.test.mjs
```

Ouvrir `http://localhost:8080`. Le portail demande l’URL de l’API et les identifiants du groupe. Les membres utilisent l’accès collectif en lecture seule. Aucun outil de compilation n’est nécessaire.

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
