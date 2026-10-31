import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/onboarding/application/onboarding_provider.dart';
import 'package:statoo/features/shared/application/shared_providers.dart';
import 'package:statoo/features/shared/data/shared_service.dart';
import 'package:statoo/features/shared/presentation/recovery_request_sheet.dart';
import 'package:statoo/features/shared/presentation/shared_group_screen.dart';
import 'package:statoo/features/team/application/team_provider.dart';

class _FakeSharedService extends SharedService {
  _FakeSharedService(super.database);
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database rawDb;
  late AppDatabase appDb;
  late _FakeSharedService fakeSharedService;
  late ProviderContainer container;

  setUp(() async {
    rawDb = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    appDb = AppDatabase.forTesting(rawDb);
    await appDb.initSchemaForTest(rawDb);

    fakeSharedService = _FakeSharedService(appDb);

    container = ProviderContainer(
      overrides: [
        sharedServiceProvider.overrideWithValue(fakeSharedService),
        hasSeenOnboardingProvider.overrideWith(
          () => OnboardingNotifier(initialValue: false),
        ),
        activeTeamIdProvider.overrideWith(ActiveTeamIdNotifier.new),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await rawDb.close();
  });

  Widget buildScreenHarness({
    bool initialCreate = false,
    bool setup = false,
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: SharedGroupScreen(
          initialCreate: initialCreate,
          setup: setup,
        ),
      ),
    );
  }

  group('Intégration du Lien de Récupération sur SharedGroupScreen', () {
    group('Visibilité selon le Mode (Rejoindre vs Créer)', () {
      testWidgets(
        'G-W-T 1.1: En mode Rejoindre (!initialCreate), le bouton « Mot de passe oublié ? » est visible',
        (tester) async {
          // Given / When
          await tester.pumpWidget(buildScreenHarness());
          await tester.pumpAndSettle();

          // Then
          expect(find.text('Mot de passe oublié ?'), findsOneWidget);
        },
      );

      testWidgets(
        'G-W-T 1.2: En mode Créer (initialCreate: true), le bouton « Mot de passe oublié ? » est ABSENT',
        (tester) async {
          // Given / When
          await tester.pumpWidget(buildScreenHarness(initialCreate: true));
          await tester.pumpAndSettle();

          // Then
          expect(find.text('Mot de passe oublié ?'), findsNothing);
        },
      );

      testWidgets(
        'G-W-T 1.3: Basculer du segment Rejoindre vers Partager masque le bouton « Mot de passe oublié ? »',
        (tester) async {
          // Given
          await tester.pumpWidget(buildScreenHarness());
          await tester.pumpAndSettle();
          expect(find.text('Mot de passe oublié ?'), findsOneWidget);

          // When : Clic sur le segment "Partager"
          await tester.tap(find.text('Partager'));
          await tester.pumpAndSettle();

          // Then
          expect(find.text('Mot de passe oublié ?'), findsNothing);
        },
      );

      testWidgets(
        'G-W-T 1.4: Re-basculer de Partager vers Rejoindre réaffiche le bouton « Mot de passe oublié ? »',
        (tester) async {
          // Given
          await tester.pumpWidget(buildScreenHarness());
          await tester.pumpAndSettle();
          await tester.tap(find.text('Partager'));
          await tester.pumpAndSettle();
          expect(find.text('Mot de passe oublié ?'), findsNothing);

          // When : Clic sur le segment "Rejoindre"
          await tester.tap(find.text('Rejoindre'));
          await tester.pumpAndSettle();

          // Then
          expect(find.text('Mot de passe oublié ?'), findsOneWidget);
        },
      );
    });

    group('Ouverture de RecoveryRequestSheet & Transmission des Valeurs', () {
      testWidgets(
        'G-W-T 2.1: Clic sur « Mot de passe oublié ? » ouvre la modal RecoveryRequestSheet',
        (tester) async {
          // Given
          await tester.pumpWidget(buildScreenHarness());
          await tester.pumpAndSettle();

          // When
          final forgotFinder = find.text('Mot de passe oublié ?');
          await tester.scrollUntilVisible(
            forgotFinder,
            50,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          await tester.tap(forgotFinder);
          await tester.pumpAndSettle();

          // Then
          expect(find.byType(RecoveryRequestSheet), findsOneWidget);
        },
      );

      testWidgets(
        'G-W-T 2.2: Ouvre la modal en pré-remplissant les champs groupe et utilisateur déjà saisis',
        (tester) async {
          // Given
          await tester.pumpWidget(buildScreenHarness());
          await tester.pumpAndSettle();

          // Saisie des identifiants sur l'écran d'accueil
          final Finder fields = find.byType(TextField);
          final Finder groupField = fields.at(0);
          final Finder userField = fields.at(1);

          await tester.enterText(groupField, 'fc_barca_5v5');
          await tester.enterText(userField, 'leo_messi');
          await tester.pumpAndSettle();

          // When : Clic sur Mot de passe oublié ?
          final forgotFinder = find.text('Mot de passe oublié ?');
          await tester.scrollUntilVisible(
            forgotFinder,
            50,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          await tester.tap(forgotFinder);
          await tester.pumpAndSettle();

          // Then : Dans RecoveryRequestSheet, les valeurs saisies sont reportées
          expect(find.byType(RecoveryRequestSheet), findsOneWidget);
          expect(find.text('fc_barca_5v5'), findsWidgets);
          expect(find.text('leo_messi'), findsWidgets);
        },
      );

      testWidgets(
        "G-W-T 2.3: Fermer la modal (pop) restaure l'écran SharedGroupScreen sans perte de saisie",
        (tester) async {
          // Given
          await tester.pumpWidget(buildScreenHarness());
          await tester.pumpAndSettle();

          final Finder fields = find.byType(TextField);
          await tester.enterText(fields.at(0), 'groupe_alpha');
          await tester.enterText(fields.at(1), 'alex_10');
          await tester.pumpAndSettle();

          final forgotFinder = find.text('Mot de passe oublié ?');
          await tester.scrollUntilVisible(
            forgotFinder,
            50,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          await tester.tap(forgotFinder);
          await tester.pumpAndSettle();
          expect(find.byType(RecoveryRequestSheet), findsOneWidget);

          // When : Fermeture de la bottom sheet (tap sur la croix de fermeture)
          final Finder closeButton = find.widgetWithIcon(IconButton, Remix.close_line);
          if (closeButton.evaluate().isNotEmpty) {
            await tester.tap(closeButton);
          } else {
            Navigator.of(tester.element(find.byType(RecoveryRequestSheet))).pop();
          }
          await tester.pumpAndSettle();

          // Then : Retour sur SharedGroupScreen avec les valeurs initiales intactes
          expect(find.byType(RecoveryRequestSheet), findsNothing);
          expect(find.text('groupe_alpha'), findsOneWidget);
          expect(find.text('alex_10'), findsOneWidget);
        },
      );
    });
  });
}
