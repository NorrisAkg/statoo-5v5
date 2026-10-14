# Mobile Statoo

Le projet Flutter complet se trouve ici : `lib/`, `test/`, `assets/`, `android/`, `ios/`, `pubspec.yaml` et `pubspec.lock`.

Exécuter Flutter et Dart depuis ce dossier :

```powershell
flutter pub get
dart run build_runner build
flutter test
flutter run
```

Le mode privé conserve SQLite local. La page « Groupe partagé » permet de créer ou rejoindre un groupe, distribuer des rôles et synchroniser les versions. Le jeton de connexion est conservé dans le stockage sécurisé du système ; les écritures en attente sont persistées dans SQLite.

L’URL par défaut peut être fournie avec `--dart-define=STATOO_API=https://votre-api.example`. L’adresse reste modifiable à la connexion. HTTP est limité au développement local ; l’émulateur Android utilise `http://10.0.2.2:8000`.

Voir [le guide commun](../docs/shared-group-and-finance.md). La synchronisation réseau et le stockage sécurisé doivent aussi être validés sur les appareils physiques avant distribution.
