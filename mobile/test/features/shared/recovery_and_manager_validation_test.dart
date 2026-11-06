import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/core/data/shared_http_error.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/players/application/players_provider.dart';
import 'package:statoo/features/players/domain/player.dart';
import 'package:statoo/features/shared/application/recovery_controller.dart';
import 'package:statoo/features/shared/application/shared_providers.dart';
import 'package:statoo/features/shared/data/shared_service.dart';
import 'package:statoo/features/shared/presentation/add_manager_bottom_sheet.dart';
import 'package:statoo/features/shared/presentation/recovery_request_sheet.dart';

class FakePlayersNotifier extends PlayersNotifier {
  FakePlayersNotifier(this._players);
  final List<Player> _players;
  @override
  Future<List<Player>> build() async => _players;
}

class MockManagerSharedService extends SharedService {
  MockManagerSharedService() : super(AppDatabase.instance) {
    baseUrl = 'https://api.test';
    identity = {
      'group_id': '#team1',
      'account': {
        'id': 'admin1',
        'roles': ['ADMIN'],
      },
    };
  }

  int requestCalls = 0;
  Exception? requestError;

  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, [
    Object? body,
  ]) async {
    requestCalls++;
    if (requestError != null) throw requestError!;
    return {'id': 'acc_1'};
  }
}

class FakeRecoveryController extends RecoveryController {
  int submitCalls = 0;
  bool shouldSucceed = true;
  String? errorToSet;

  @override
  Future<bool> submitRecovery({
    required String url,
    required String groupId,
    required String username,
    required String recoveryCode,
    required String newPassword,
    required String confirmPassword,
  }) async {
    submitCalls++;
    if (!shouldSucceed) {
      state = state.copyWith(
        step: RecoveryStep.error,
        errorMessage: errorToSet ?? 'Code de secours invalide',
      );
      return false;
    }
    state = state.copyWith(
      step: RecoveryStep.completed,
      newRecoveryCode: 'NEW-1234',
    );
    return true;
  }
}

void main() {
  group('AddManagerBottomSheet - Validation et Toasts', () {
    late MockManagerSharedService mockService;
    final testPlayers = [
      Player(
        id: 'p1',
        teamId: '#team1',
        name: 'Bob Test',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    setUp(() {
      mockService = MockManagerSharedService();
    });

    testWidgets('identifiant vide = erreur locale et aucun appel reseau', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedServiceProvider.overrideWithValue(mockService),
            playersListProvider.overrideWith(() => FakePlayersNotifier(testPlayers)),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: AddManagerBottomSheet()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Trésorier'));
      await tester.pumpAndSettle();

      final searchField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Membre',
      );
      await tester.enterText(searchField, 'Bob');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bob Test').last);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Créer'));
      await tester.pumpAndSettle();

      expect(mockService.requestCalls, 0);
      expect(find.text('Saisissez un identifiant.'), findsOneWidget);
    });

    testWidgets('erreur backend 409 conflit affiche un showTopToast en haut', (tester) async {
      mockService.requestError = const SharedApiException(409, 'Compte en double');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedServiceProvider.overrideWithValue(mockService),
            playersListProvider.overrideWith(() => FakePlayersNotifier(testPlayers)),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: AddManagerBottomSheet()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Identifiant'), 'bob');
      await tester.tap(find.text('Trésorier'));
      await tester.pumpAndSettle();

      final searchField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Membre',
      );
      await tester.enterText(searchField, 'Bob');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bob Test').last);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Créer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(mockService.requestCalls, 1);
      expect(find.textContaining('déjà associé à un compte'), findsOneWidget);
    });
  });

  group('RecoveryRequestSheet - Validation granulaire et showTopToast', () {
    late FakeRecoveryController fakeController;

    setUp(() {
      fakeController = FakeRecoveryController();
    });

    testWidgets('champs vides = messages d erreur sous chaque champ et pas d appel API', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            recoveryControllerProvider.overrideWith(() => fakeController),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: RecoveryRequestSheet()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final submitBtn = find.widgetWithText(ElevatedButton, 'Réinitialiser');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(fakeController.submitCalls, 0);

      expect(find.textContaining('groupe requis'), findsOneWidget);
      expect(find.textContaining('utilisateur requis'), findsOneWidget);
      expect(find.textContaining('secours requis'), findsOneWidget);
      expect(find.textContaining('passe requis'), findsAtLeastNWidgets(1));
    });

    testWidgets('erreur serveur de reinitialisation declenche showTopToast', (tester) async {
      fakeController
        ..shouldSucceed = false
        ..errorToSet = 'Code de secours invalide';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            recoveryControllerProvider.overrideWith(() => fakeController),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: RecoveryRequestSheet(
                initialGroupId: '#12345678',
                initialUsername: 'alice',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(2), 'ABCD-1234-EFGH-5678');
      await tester.enterText(textFields.at(3), 'NouveauPasse123!');
      await tester.enterText(textFields.at(4), 'NouveauPasse123!');
      await tester.pumpAndSettle();

      final submitBtn = find.widgetWithText(ElevatedButton, 'Réinitialiser');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(fakeController.submitCalls, 1);
      expect(find.textContaining('Code de secours invalide'), findsOneWidget);
    });
  });
}
