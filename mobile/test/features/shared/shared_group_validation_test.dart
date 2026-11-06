import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/core/data/shared_http_error.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/shared/application/shared_providers.dart';
import 'package:statoo/features/shared/data/shared_service.dart';
import 'package:statoo/features/shared/presentation/shared_group_screen.dart';
import 'package:statoo/features/team/application/team_provider.dart';

class MockSharedService extends SharedService {
  MockSharedService() : super(AppDatabase.instance);

  int connectCalls = 0;
  Exception? connectError;

  @override
  Future<void> connect(
    String url,
    String group,
    String username,
    String password, {
    Map<String, dynamic>? registration,
  }) async {
    connectCalls++;
    if (connectError != null) throw connectError!;
  }
}

void main() {
  late MockSharedService mockService;

  setUp(() {
    mockService = MockSharedService();
  });

  group('SharedGroupScreen - Validations et Toasts', () {
    testWidgets('Rejoindre : champs vides = aucun appel reseau et messages errorText sous les champs', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedServiceProvider.overrideWithValue(mockService),
            activeTeamIdProvider.overrideWith(ActiveTeamIdNotifier.new),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const SharedGroupScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final connectBtn = find.text('Se connecter');
      await tester.ensureVisible(connectBtn);
      await tester.tap(connectBtn);
      await tester.pumpAndSettle();

      expect(mockService.connectCalls, 0, reason: 'Aucun appel reseau ne doit etre effectue si les champs sont vides');

      expect(find.textContaining("l'identifiant du groupe"), findsOneWidget);
      expect(find.textContaining('identifiant'), findsAtLeastNWidgets(1));
      expect(find.textContaining('mot de passe'), findsAtLeastNWidgets(1));
    });

    testWidgets('Partager : champs vides ou mots de passe < 8 chars = validation client bloquante', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedServiceProvider.overrideWithValue(mockService),
            activeTeamIdProvider.overrideWith(() => ActiveTeamIdNotifier(initialValue: 'team_local_1')),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const SharedGroupScreen(initialCreate: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final createBtn = find.text('Créer le groupe partagé');
      await tester.ensureVisible(createBtn);
      await tester.tap(createBtn);
      await tester.pumpAndSettle();

      expect(mockService.connectCalls, 0);
      expect(find.textContaining('identifiant'), findsAtLeastNWidgets(1));

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'adminUser');
      await tester.enterText(textFields.at(1), 'court');
      await tester.enterText(textFields.at(2), 'membres');
      await tester.enterText(textFields.at(3), '1234');

      await tester.tap(createBtn);
      await tester.pumpAndSettle();

      expect(mockService.connectCalls, 0);
      expect(find.textContaining('8 caractères'), findsAtLeastNWidgets(1));
    });

    testWidgets('Rejoindre : echec serveur (401/reseau) declenche showTopToast', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      mockService.connectError = const SharedApiException(401, 'Identifiants invalides');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedServiceProvider.overrideWithValue(mockService),
            activeTeamIdProvider.overrideWith(ActiveTeamIdNotifier.new),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const SharedGroupScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '#12345678');
      await tester.enterText(textFields.at(1), 'alice');
      await tester.enterText(textFields.at(2), 'MonSuperMotDePasse8!');

      final connectBtn = find.text('Se connecter');
      await tester.ensureVisible(connectBtn);
      await tester.tap(connectBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(mockService.connectCalls, 1);
      expect(find.textContaining('Identifiants invalides'), findsOneWidget);
    });
  });
}
