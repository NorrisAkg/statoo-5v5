import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/core/data/shared_http_error.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/core/widgets/primary_button.dart';
import 'package:statoo/features/shared/application/recovery_controller.dart';
import 'package:statoo/features/shared/application/shared_providers.dart';
import 'package:statoo/features/shared/data/shared_service.dart';
import 'package:statoo/features/shared/presentation/recovery_confirmation_sheet.dart';
import 'package:statoo/features/shared/presentation/recovery_request_sheet.dart';
import 'package:statoo/features/shared/presentation/widgets/password_complexity_indicator.dart';
import 'package:statoo/features/team/application/team_provider.dart';
import 'package:statoo/features/team/data/team_repository.dart';
import 'package:statoo/features/team/domain/team_info.dart';

class _FakeSharedService extends SharedService {
  _FakeSharedService(
    super.database);

  Map<String, dynamic> Function({
    required String url,
    required String groupId,
    required String username,
    required String recoveryCode,
    required String newPassword,
    required String newRecoveryCode,
  })? onRecover;

  Future<void> Function(String url, Map<String, dynamic> sessionResult)?
      onEstablishSession;

  int recoverCallCount = 0;
  int establishSessionCallCount = 0;

  @override
  Future<Map<String, dynamic>> recover({
    required String url,
    required String groupId,
    required String username,
    required String recoveryCode,
    required String newPassword,
    required String newRecoveryCode,
  }) async {
    recoverCallCount++;
    if (onRecover != null) {
      return onRecover!(
        url: url,
        groupId: groupId,
        username: username,
        recoveryCode: recoveryCode,
        newPassword: newPassword,
        newRecoveryCode: newRecoveryCode,
      );
    }
    return <String, dynamic>{
      'token': 'test_token',
      'expires_at':
          DateTime.now().add(const Duration(days: 1)).toUtc().toIso8601String(),
      'group_id': groupId,
      'account': <String, dynamic>{
        'id': 'acc_1',
        'username': username,
        'roles': <String>['ADMIN'],
      },
      'recovery_rotated': true,
    };
  }

  @override
  Future<void> establishSession(
    String url,
    Map<String, dynamic> sessionResult,
  ) async {
    establishSessionCallCount++;
    if (onEstablishSession != null) {
      await onEstablishSession!(url, sessionResult);
      return;
    }
    identity = sessionResult;
    baseUrl = url;
    token = sessionResult['token'] as String?;
  }
}

class _FakeTeamRepository implements TeamRepository {
  final Map<String, TeamInfo> teams = <String, TeamInfo>{};
  String? activeTeamId;

  @override
  Future<TeamInfo?> getTeamById(String id) async => teams[id];

  @override
  Future<List<TeamInfo>> getAllTeams() async => teams.values.toList();

  @override
  Future<TeamInfo?> getActiveTeam() async =>
      activeTeamId != null ? teams[activeTeamId] : null;

  @override
  Future<String?> getActiveTeamId() async => activeTeamId;

  @override
  Future<void> setActiveTeamId(String id) async {
    activeTeamId = id;
  }

  @override
  Future<TeamInfo?> getTeamInfo() => getActiveTeam();

  @override
  Future<void> saveTeamInfo(TeamInfo team) async {
    teams[team.id] = team;
  }

  @override
  Future<void> deleteTeam(String id) async {
    teams.remove(id);
    if (activeTeamId == id) activeTeamId = null;
  }

  @override
  Future<Map<String, int>> getTeamCounts(String teamId) async =>
      <String, int>{};
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database rawDb;
  late AppDatabase appDb;
  late _FakeSharedService fakeSharedService;
  late _FakeTeamRepository fakeTeamRepository;
  late ProviderContainer container;

  setUp(() async {
    rawDb = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    appDb = AppDatabase.forTesting(rawDb);
    await appDb.initSchemaForTest(rawDb);

    fakeSharedService = _FakeSharedService(appDb);
    fakeTeamRepository = _FakeTeamRepository();

    container = ProviderContainer(
      overrides: [
        sharedServiceProvider.overrideWithValue(fakeSharedService),
        teamRepositoryProvider.overrideWithValue(fakeTeamRepository),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await rawDb.close();
  });

  Widget buildRequestSheetHarness({
    String? initialGroupId,
    String? initialUsername,
    void Function(String newCode)? onSuccess,
    ThemeData? theme,
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: theme ?? AppTheme.darkTheme,
        home: Scaffold(
          body: RecoveryRequestSheet(
            initialGroupId: initialGroupId,
            initialUsername: initialUsername,
            onSuccess: onSuccess,
          ),
        ),
      ),
    );
  }

  Widget buildConfirmationSheetHarness({
    required String newRecoveryCode,
    VoidCallback? onCompleted,
    ThemeData? theme,
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: theme ?? AppTheme.darkTheme,
        home: Scaffold(
          body: RecoveryConfirmationSheet(
            newRecoveryCode: newRecoveryCode,
            onCompleted: onCompleted,
          ),
        ),
      ),
    );
  }

  group('RecoveryRequestSheet', () {
    group('Pré-remplissage et Affichage Initial', () {
      testWidgets(
        'G-W-T 1.1: Pré-remplit les champs groupe et utilisateur avec les valeurs initiales fournies',
        (tester) async {
          // Given / When
          await tester.pumpWidget(
            buildRequestSheetHarness(
              initialGroupId: 'team_alpha',
              initialUsername: 'capitaine',
            ),
          );
          await tester.pumpAndSettle();

          // Then
          expect(find.text('team_alpha'), findsOneWidget);
          expect(find.text('capitaine'), findsOneWidget);
        },
      );

      testWidgets(
        'G-W-T 1.2: Affiche des champs vides lorsque les valeurs initiales sont absentes (null)',
        (tester) async {
          // Given / When
          await tester.pumpWidget(
            buildRequestSheetHarness(
              
            ),
          );
          await tester.pumpAndSettle();

          // Then
          final Finder textFields = find.byType(TextField);
          expect(textFields, findsNWidgets(5));
          for (final Element element in textFields.evaluate()) {
            final TextField field = element.widget as TextField;
            expect(field.controller?.text ?? '', isEmpty);
          }
        },
      );

      testWidgets(
        'G-W-T 1.3: Contient les 5 champs obligatoires de formulaire avec leurs étiquettes',
        (tester) async {
          // Given / When
          await tester.pumpWidget(buildRequestSheetHarness());
          await tester.pumpAndSettle();

          // Then
          expect(find.textContaining('groupe'), findsWidgets);
          expect(find.textContaining('utilisateur'), findsWidgets);
          expect(find.textContaining('secours'), findsWidgets);
          expect(find.textContaining('Nouveau mot de passe'), findsWidgets);
          expect(find.textContaining('Confirmation'), findsWidgets);
        },
      );

      testWidgets(
        'G-W-T 1.4: Intègre le composant PasswordComplexityIndicator',
        (tester) async {
          // Given / When
          await tester.pumpWidget(buildRequestSheetHarness());
          await tester.pumpAndSettle();

          // Then
          expect(find.byType(PasswordComplexityIndicator), findsOneWidget);
        },
      );
    });

    group('Bascule Afficher / Masquer le Mot de Passe', () {
      testWidgets(
        "G-W-T 2.1: Le mot de passe et la confirmation sont masqués par défaut avec l'icône eye_line",
        (tester) async {
          // Given / When
          await tester.pumpWidget(buildRequestSheetHarness());
          await tester.pumpAndSettle();

          // Then
          expect(find.byIcon(Remix.eye_line), findsNWidgets(2));
          expect(find.byIcon(Remix.eye_off_line), findsNothing);
        },
      );

      testWidgets(
        "G-W-T 2.2: Clic sur l'icône bascule le nouveau mot de passe en clair (obscureText: false)",
        (tester) async {
          // Given
          await tester.pumpWidget(buildRequestSheetHarness());
          await tester.pumpAndSettle();

          // When
          final Finder eyeIcons = find.byIcon(Remix.eye_line);
          await tester.tap(eyeIcons.first);
          await tester.pumpAndSettle();

          // Then
          expect(find.byIcon(Remix.eye_off_line), findsOneWidget);
          expect(find.byIcon(Remix.eye_line), findsOneWidget);
        },
      );

      testWidgets(
        'G-W-T 2.3: Un second clic re-masque le mot de passe (obscureText: true)',
        (tester) async {
          // Given
          await tester.pumpWidget(buildRequestSheetHarness());
          await tester.pumpAndSettle();

          // When
          await tester.tap(find.byIcon(Remix.eye_line).first);
          await tester.pumpAndSettle();
          await tester.tap(find.byIcon(Remix.eye_off_line));
          await tester.pumpAndSettle();

          // Then
          expect(find.byIcon(Remix.eye_line), findsNWidgets(2));
          expect(find.byIcon(Remix.eye_off_line), findsNothing);
        },
      );
    });

    group("Validation Locale & Messages d'Erreur", () {
      testWidgets(
        'G-W-T 3.1: Clic sur « Réinitialiser » avec champs vides affiche une erreur sans appel réseau',
        (tester) async {
          // Given
          await tester.pumpWidget(buildRequestSheetHarness());
          await tester.pumpAndSettle();

          // When
          final submitFinder = find.widgetWithText(PrimaryButton, 'Réinitialiser');
          await tester.ensureVisible(submitFinder);
          await tester.tap(submitFinder);
          await tester.pumpAndSettle();

          // Then
          expect(fakeSharedService.recoverCallCount, equals(0));
          expect(
            find.textContaining('Veuillez renseigner tous les champs'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        "G-W-T 3.2: Clic avec mot de passe et confirmation différents affiche l'erreur de mismatch",
        (tester) async {
          // Given
          await tester.pumpWidget(buildRequestSheetHarness());
          await tester.pumpAndSettle();

          final Finder fields = find.byType(TextField);
          await tester.enterText(fields.at(0), 'grp_1');
          await tester.enterText(fields.at(1), 'alex');
          await tester.enterText(fields.at(2), '2345-6789-ABCD-EFGH');
          await tester.enterText(fields.at(3), 'ValidPass123!');
          await tester.enterText(fields.at(4), 'DifferentPass456!');
          await tester.pumpAndSettle();

          // When
          final submitFinder = find.widgetWithText(PrimaryButton, 'Réinitialiser');
          await tester.ensureVisible(submitFinder);
          await tester.tap(submitFinder);
          await tester.pumpAndSettle();

          // Then
          expect(fakeSharedService.recoverCallCount, equals(0));
          expect(
            find.textContaining('Les mots de passe ne correspondent pas'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        "G-W-T 3.3: Clic avec mot de passe ne respectant pas les critères affiche l'erreur de sécurité",
        (tester) async {
          // Given
          await tester.pumpWidget(buildRequestSheetHarness());
          await tester.pumpAndSettle();

          final Finder fields = find.byType(TextField);
          await tester.enterText(fields.at(0), 'grp_1');
          await tester.enterText(fields.at(1), 'alex');
          await tester.enterText(fields.at(2), '2345-6789-ABCD-EFGH');
          await tester.enterText(fields.at(3), 'short');
          await tester.enterText(fields.at(4), 'short');
          await tester.pumpAndSettle();

          // When
          final submitFinder = find.widgetWithText(PrimaryButton, 'Réinitialiser');
          await tester.ensureVisible(submitFinder);
          await tester.tap(submitFinder);
          await tester.pumpAndSettle();

          // Then
          expect(fakeSharedService.recoverCallCount, equals(0));
          expect(
            find.textContaining('critères de sécurité'),
            findsOneWidget,
          );
        },
      );
    });

    group('Soumission et Gestion des Retours API', () {
      testWidgets(
        'G-W-T 4.1: Clic valide déclenche submitRecovery et appelle onSuccess avec le nouveau code généré',
        (tester) async {
          // Given
          String? reportedNewCode;
          await tester.pumpWidget(
            buildRequestSheetHarness(
              initialGroupId: 'team_alpha',
              initialUsername: 'alex',
              onSuccess: (code) => reportedNewCode = code,
            ),
          );
          await tester.pumpAndSettle();

          final Finder fields = find.byType(TextField);
          await tester.enterText(fields.at(2), '2345-6789-ABCD-EFGH');
          await tester.enterText(fields.at(3), 'StrongPass123!');
          await tester.enterText(fields.at(4), 'StrongPass123!');
          await tester.pumpAndSettle();

          // When
          final submitFinder = find.widgetWithText(PrimaryButton, 'Réinitialiser');
          await tester.ensureVisible(submitFinder);
          await tester.tap(submitFinder);
          await tester.pumpAndSettle();

          // Then
          expect(fakeSharedService.recoverCallCount, equals(1));
          expect(reportedNewCode, isNotNull);
          expect(reportedNewCode, isNot(equals('2345-6789-ABCD-EFGH')));
        },
      );

      testWidgets(
        "G-W-T 4.2: Affiche l'erreur API retournée par le serveur en cas de code invalide",
        (tester) async {
          // Given
          fakeSharedService.onRecover = ({
            required url,
            required groupId,
            required username,
            required recoveryCode,
            required newPassword,
            required newRecoveryCode,
          }) {
            throw const SharedApiException(
              401,
              'Code de secours ou identifiant incorrect.',
            );
          };

          await tester.pumpWidget(
            buildRequestSheetHarness(
              initialGroupId: 'team_alpha',
              initialUsername: 'alex',
            ),
          );
          await tester.pumpAndSettle();

          final Finder fields = find.byType(TextField);
          await tester.enterText(fields.at(2), '2345-6789-ABCD-EFGH');
          await tester.enterText(fields.at(3), 'StrongPass123!');
          await tester.enterText(fields.at(4), 'StrongPass123!');
          await tester.pumpAndSettle();

          // When
          final submitFinder = find.widgetWithText(PrimaryButton, 'Réinitialiser');
          await tester.ensureVisible(submitFinder);
          await tester.tap(submitFinder);
          await tester.pumpAndSettle();

          // Then
          expect(
            find.textContaining('Code de secours ou identifiant incorrect'),
            findsOneWidget,
          );
        },
      );
    });

    group('Non-régression Responsive & Clavier Virtuel', () {
      testWidgets(
        'G-W-T 5.1: Se rend sans overflow sur écran compact 320dp',
        (tester) async {
          // Given
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          // When
          await tester.pumpWidget(buildRequestSheetHarness());
          await tester.pumpAndSettle();

          // Then
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'G-W-T 5.2: Se rend sans overflow sur écran standard 393dp',
        (tester) async {
          // Given
          tester.view.physicalSize = const Size(393, 852);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          // When
          await tester.pumpWidget(buildRequestSheetHarness());
          await tester.pumpAndSettle();

          // Then
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'G-W-T 5.3: Se redimensionne sans RenderFlex overflow avec clavier virtuel simulé (viewInsets.bottom = 300)',
        (tester) async {
          // Given
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1.0;
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            tester.view.resetViewInsets();
          });

          // When
          await tester.pumpWidget(buildRequestSheetHarness());
          await tester.pumpAndSettle();

          // Then
          expect(tester.takeException(), isNull);
        },
      );
    });
  });

  group('RecoveryConfirmationSheet', () {
    const String testRecoveryCode = 'ABCD-EFGH-JKMN-PQRS';

    group('Affichage du Nouveau Code & Presse-papiers', () {
      testWidgets(
        'G-W-T 6.1: Affiche le nouveau code généré en grand et lisiblement',
        (tester) async {
          // Given / When
          await tester.pumpWidget(
            buildConfirmationSheetHarness(newRecoveryCode: testRecoveryCode),
          );
          await tester.pumpAndSettle();

          // Then
          expect(find.text(testRecoveryCode), findsOneWidget);
        },
      );

      testWidgets(
        'G-W-T 6.2: Clic sur le bouton « Copier » copie le code dans le presse-papiers',
        (tester) async {
          // Given
          final List<MethodCall> calls = <MethodCall>[];
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            (call) async {
              calls.add(call);
              return null;
            },
          );
          addTearDown(
            () => tester.binding.defaultBinaryMessenger
                .setMockMethodCallHandler(SystemChannels.platform, null),
          );

          await tester.pumpWidget(
            buildConfirmationSheetHarness(newRecoveryCode: testRecoveryCode),
          );
          await tester.pumpAndSettle();

          // When
          await tester.tap(find.widgetWithText(OutlinedButton, 'Copier'));
          await tester.pump();

          // Then
          expect(calls.where((c) => c.method == 'Clipboard.setData'), isNotEmpty);
          expect(
            calls.firstWhere((c) => c.method == 'Clipboard.setData').arguments,
            equals(<String, dynamic>{'text': testRecoveryCode}),
          );
          expect(find.textContaining('copié'), findsWidgets);
        },
      );
    });

    group('Case à Cocher Obligatoire & Activation du Bouton', () {
      testWidgets(
        'G-W-T 7.1: Affiche la case à cocher obligatoire décochée par défaut',
        (tester) async {
          // Given / When
          await tester.pumpWidget(
            buildConfirmationSheetHarness(newRecoveryCode: testRecoveryCode),
          );
          await tester.pumpAndSettle();

          // Then
          final Checkbox checkbox = tester.widget(find.byType(Checkbox));
          expect(checkbox.value, isFalse);
          expect(
            find.textContaining(
              "J'ai bien noté mon nouveau code de secours dans un endroit sûr",
            ),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        "G-W-T 7.2: Le bouton principal « Accéder à mon groupe » est DÉSACTIVÉ tant que la case n'est pas cochée",
        (tester) async {
          // Given / When
          await tester.pumpWidget(
            buildConfirmationSheetHarness(newRecoveryCode: testRecoveryCode),
          );
          await tester.pumpAndSettle();

          // Then
          final PrimaryButton button = tester.widget(
            find.widgetWithText(PrimaryButton, 'Accéder à mon groupe'),
          );
          expect(button.onPressed, isNull);
        },
      );

      testWidgets(
        'G-W-T 7.3: Cocher la case ACTIVE immédiatement le bouton « Accéder à mon groupe »',
        (tester) async {
          // Given
          await tester.pumpWidget(
            buildConfirmationSheetHarness(newRecoveryCode: testRecoveryCode),
          );
          await tester.pumpAndSettle();

          // When
          await tester.tap(find.byType(Checkbox));
          await tester.pumpAndSettle();

          // Then
          final PrimaryButton button = tester.widget(
            find.widgetWithText(PrimaryButton, 'Accéder à mon groupe'),
          );
          expect(button.onPressed, isNotNull);
        },
      );

      testWidgets(
        'G-W-T 7.4: Décocher la case RE-DÉSACTIVE immédiatement le bouton principal',
        (tester) async {
          // Given
          await tester.pumpWidget(
            buildConfirmationSheetHarness(newRecoveryCode: testRecoveryCode),
          );
          await tester.pumpAndSettle();

          // When : Coche puis décoche
          await tester.tap(find.byType(Checkbox));
          await tester.pumpAndSettle();
          await tester.tap(find.byType(Checkbox));
          await tester.pumpAndSettle();

          // Then
          final PrimaryButton button = tester.widget(
            find.widgetWithText(PrimaryButton, 'Accéder à mon groupe'),
          );
          expect(button.onPressed, isNull);
        },
      );
    });

    group('Connexion & Finalisation', () {
      testWidgets(
        'G-W-T 8.1: Clic sur le bouton actif appelle confirmCodeAndConnect et déclenche onCompleted',
        (tester) async {
          // Given : Soumission préalable dans le contrôleur pour avoir awaitingConfirmation
          await container.read(recoveryControllerProvider.notifier).submitRecovery(
                url: 'https://api.statoo.app',
                groupId: 'grp_1',
                username: 'alex',
                recoveryCode: '2345-6789-ABCD-EFGH',
                newPassword: 'StrongPass123!',
                confirmPassword: 'StrongPass123!',
              );

          bool completedCalled = false;
          await tester.pumpWidget(
            buildConfirmationSheetHarness(
              newRecoveryCode: testRecoveryCode,
              onCompleted: () => completedCalled = true,
            ),
          );
          await tester.pumpAndSettle();

          // When
          final checkboxFinder = find.byType(Checkbox);
          await tester.ensureVisible(checkboxFinder);
          await tester.tap(checkboxFinder);
          await tester.pumpAndSettle();
          final buttonFinder =
              find.widgetWithText(PrimaryButton, 'Accéder à mon groupe');
          await tester.ensureVisible(buttonFinder);
          await tester.tap(buttonFinder);
          await tester.pumpAndSettle();

          // Then
          expect(fakeSharedService.establishSessionCallCount, equals(1));
          expect(completedCalled, isTrue);
        },
      );
    });

    group('Responsive 320dp et 393dp Confirmation', () {
      testWidgets(
        'G-W-T 9.1: Se rend sans overflow sur 320dp',
        (tester) async {
          // Given
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          // When
          await tester.pumpWidget(
            buildConfirmationSheetHarness(newRecoveryCode: testRecoveryCode),
          );
          await tester.pumpAndSettle();

          // Then
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'G-W-T 9.2: Se rend sans overflow sur 393dp',
        (tester) async {
          // Given
          tester.view.physicalSize = const Size(393, 852);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          // When
          await tester.pumpWidget(
            buildConfirmationSheetHarness(newRecoveryCode: testRecoveryCode),
          );
          await tester.pumpAndSettle();

          // Then
          expect(tester.takeException(), isNull);
        },
      );
    });
  });
}
