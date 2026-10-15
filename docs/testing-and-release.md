# Tests et livraison

Inventaire au 12 octobre 2026. Tests, analyse Flutter et builds non exécutés lors de l'onboarding documentaire ; leurs résultats actuels restent à mesurer.

## Tests

Depuis le 14 octobre 2026, le workflow demandé est le TDD : voir [les conventions](conventions.md) et [les scénarios des huit majeurs UI/UX](tdd-majeurs-ui-ux.md). Les inventaires et résultats historiques ci-dessous ne remplacent pas une exécution actuelle. Un scénario spécifié n'est pas un test exécuté.

Pour le lot UX01–UX08, les résultats observés, le changement de contrat d'approbation serveur et les vérifications appareil restantes sont consignés dans le [journal TDD](tdd-majeurs-journal.md).

31 fichiers *test.dart : règles/calculs purs, widgets avec overrides Riverpod et SQLite en mémoire via sqflite_common_ffi.

| Sujet | Exemple |
|---|---|
| Navigation | `test/widget_test.dart` |
| Isolation | `test/features/team/tenant_isolation_test.dart` |
| Clôture | `test/features/sessions/session_close_test.dart` |
| Tournoi | `test/features/sessions/tournament_3_teams_test.dart` |
| Score/buteur | `test/features/sessions/goal_score_sync_test.dart` |
| Composition | `test/features/sessions/live_roster_editing_test.dart` |
| Classement | `test/features/ranking/standings_per_match_view_test.dart` |
| MVP | `test/features/ranking/monthly_mvp_repository_test.dart` |
| Backup | `test/features/settings/backup_service_test.dart` |

Aucun test onUpgrade, golden test ou répertoire integration_test repéré. initSchemaForTest valide un schéma frais. Les chiffres d'analyse/tests des audits de septembre sont historiques.

```powershell
flutter pub get
flutter analyze
flutter test
flutter test test/features/settings/
flutter test test/features/team/tenant_isolation_test.dart
```

Pour une livraison, compléter par parcours sur appareil et migrations de copies des versions distribuées. Les objectifs CDC < 2 s au démarrage et < 2 min de saisie ne sont pas mesurés actuellement.

## Android

Configuration : com.kysolutions.statoo, Java/JVM 17, AGP 9.1.0, Kotlin 2.4.0, Gradle 9.3.1. SDK Android et version transmis par Flutter ; pubspec.yaml déclare 1.0.0+1.

La signature lit android/key.properties : keyAlias, keyPassword, storeFile, storePassword. Le fichier et les keystores sont ignorés par Git. Sans configuration, release utilise la clé debug : vérifier le certificat avant publication. Ne pas versionner les secrets.

```powershell
flutter build apk --release
flutter build appbundle --release
```

Sources : `android/app/build.gradle.kts`, `android/settings.gradle.kts`, `android/gradle/wrapper/gradle-wrapper.properties`, `android/.gitignore`, `pubspec.yaml`.

## iOS et automatisation

Projet Xcode et RunnerTests présents. Compilation/signature nécessitent macOS/Xcode configurés. Distribution TestFlight/App Store et identité de signature ne sont pas documentées. Info.plist autorise le paysage ; descriptions d'accès photo non repérées alors que la galerie est utilisée. Vérifier ce parcours sur appareil.

Aucun pipeline .github ni Fastlane versionné trouvé. La distribution réelle reste à confirmer. Documenter pour chaque release : commit, SDK/dépendances, analyse/tests, certificat/profil, appareils vérifiés et compatibilité DB/backups. Un APK présent dans build ne prouve pas une validation.

Sources : `ios/Runner/Info.plist`, `ios/Runner.xcodeproj/project.pbxproj`, `ios/RunnerTests/RunnerTests.swift`, `lib/features/players/presentation/new_player_bottom_sheet.dart`.

## Vérification de la personnalisation des équipes

Le test team_appearance_test.dart ajouté après l'inventaire initial porte le total à 32 fichiers. Il vérifie la migration additive v7 vers v8 (pas toute la chaîne onUpgrade), les doublons, les valeurs par défaut, la palette et la persistance via backup. Le formulaire réel vérifie le blocage du bouton sur noms/couleurs identiques. 90 tests séances/backup et ce nouveau scénario formulaire passent ; l'analyse ciblée base/séances est sans problème. La validation sur appareil reste distincte de ces tests.
