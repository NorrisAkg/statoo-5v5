# Statoo

Application mobile Flutter de suivi de football entre amis : groupes, joueurs, compositions, séances, scores, statistiques et classements. Les données restent dans SQLite local. Les sauvegardes sont des fichiers JSON partagés depuis le téléphone ; aucun backend métier ni synchronisation cloud n'est branché dans le code actuel.

## Démarrer

Prérequis : Flutter avec Dart compatible avec `^3.13.4`, SDK Android ; macOS et Xcode pour iOS. Le SDK Flutter exact de release reste à confirmer. `.metadata` enregistre la révision de création, pas un verrouillage du SDK ; `pubspec.lock` conserve les dépendances résolues.

```powershell
flutter --version
flutter doctor
flutter pub get
flutter devices
flutter run
```

Au premier lancement, suivre l'onboarding puis créer un groupe ou restaurer une sauvegarde. Les données de démonstration ne sont pas injectées automatiquement en production.

## Développer et vérifier

```powershell
# Après modification Freezed/JSON ou providers annotés
dart run build_runner build --delete-conflicting-outputs
dart analyze lib/features/sessions
flutter analyze
flutter test
flutter test test/features/sessions/
```

Ne pas modifier manuellement les fichiers `*.g.dart` et `*.freezed.dart`. Ces commandes décrivent les procédures ; elles n'ont pas été exécutées lors de l'onboarding documentaire du 12 octobre 2026.

## Structure et documentation

`lib/core/` contient base, router, thème et widgets ; `lib/features/` regroupe home, onboarding, team, players, sessions, ranking, stats et settings. `test/` contient tests métier, widgets et SQLite ; `android/` et `ios/` les projets natifs ; `assets/` les images et polices Poppins.

- [Architecture et modules](docs/architecture.md)
- [Règles et workflows métier](docs/business-rules.md)
- [Données et migrations](docs/database.md)
- [Conventions](docs/conventions.md)
- [Sauvegarde et restauration](docs/backup.md)
- [Tests et livraison](docs/testing-and-release.md)
- [Décisions, risques et questions ouvertes](docs/decisions-and-risks.md)

Ces documents décrivent le code examiné sur `refonte`, à partir de `40f13fc`. Ils distinguent faits, risques non reproduits et décisions à confirmer. Le [CDC](docs/Statoo_Cahier_des_Charges_v1.1.pdf), le [brief initial](specs/prompt-agent-flutter-statoo.md) et les audits de septembre restent des références historiques ; leurs écarts avec le code sont recensés dans le registre.

## Construire Android

```powershell
flutter build apk --release
flutter build appbundle --release
```

La signature lit `android/key.properties`, exclu de Git avec les keystores. Sans cette configuration, le build release utilise la clé debug : un build réussi ne prouve pas qu'il est prêt à publier. Voir la procédure de livraison.

Sources : `pubspec.yaml`, `pubspec.lock`, `.metadata`, `lib/main.dart`, `lib/core/data/app_database.dart`, `lib/features/settings/data/backup_service.dart`, `android/app/build.gradle.kts`.
