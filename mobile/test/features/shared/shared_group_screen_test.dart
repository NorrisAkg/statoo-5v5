import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/shared/application/shared_providers.dart';
import 'package:statoo/features/shared/data/shared_service.dart';
import 'package:statoo/features/shared/presentation/shared_group_screen.dart';
import 'package:statoo/features/players/application/players_provider.dart';
import 'package:statoo/features/players/domain/player.dart';

class _AccountPlayers extends PlayersNotifier {
  @override
  Future<List<Player>> build() async => [
    Player(
      id: 'a',
      teamId: 'g',
      name: 'Alice',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ];
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets('PAR18 every connection input keeps an explanatory placeholder', (tester) async {
    final service = SharedService(AppDatabase.instance);
    await tester.pumpWidget(ProviderScope(
      overrides: [sharedServiceProvider.overrideWithValue(service)],
      child: MaterialApp(theme: AppTheme.lightTheme, home: const SharedGroupScreen()),
    ));
    await tester.pumpAndSettle();
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.decoration?.hintText?.trim(), isNot(isIn([null, ''])));
    }
    service.dispose();
  });
  testWidgets(
    'CPT-06/07 individual creation requires member and responsibility',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = SharedService(AppDatabase.instance)
        ..identity = {
          'group_id': 'g',
          'account': {
            'id': 'me',
            'roles': ['ADMIN', 'MEMBER'],
          },
        }
        ..snapshot = {
          'name': 'Notre groupe',
          'documents': <String, dynamic>{},
          'accounts': <dynamic>[],
        };
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedServiceProvider.overrideWithValue(service),
            playersListProvider.overrideWith(_AccountPlayers.new),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const SharedGroupScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Les simples membres utilisent l’accès collectif en lecture seule.',
        ),
        findsOneWidget,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SharedGroupScreen)),
      );
      await container.read(playersListProvider.future);
      await tester.tap(find.text('Ajouter un gestionnaire'));
      await tester.pumpAndSettle();
      final create = find.widgetWithText(FilledButton, 'Créer');
      expect(tester.widget<FilledButton>(create).onPressed, isNull);
      expect(
        find.text('Sélectionnez au moins un rôle de responsable.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Secrétaire général').first);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(create).onPressed, isNull);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alice').last);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(create).onPressed, isNotNull);
      await tester.tap(find.text('Secrétaire général').first);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(create).onPressed, isNull);
    },
  );
  for (final dark in [false, true]) {
    testWidgets(
      'join and share forms remain usable on a narrow screen (dark: $dark)',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final service = SharedService(AppDatabase.instance);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [sharedServiceProvider.overrideWithValue(service)],
            child: MaterialApp(
              theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
              home: const SharedGroupScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Identifiant du groupe'), findsOneWidget);
        expect(find.text('Accès des membres'), findsNothing);
        expect(find.text('Serveur'), findsNothing);
        expect(find.text('Adresse du serveur'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Partager'));
        await tester.pumpAndSettle();
        expect(find.text('Identifiant du groupe'), findsNothing);
        expect(find.text('Accès des membres'), findsOneWidget);
        expect(find.text('Serveur'), findsNothing);
        expect(find.text('Connexion à Statoo'), findsNothing);
        expect(find.text('Adresse du serveur'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final admin in [false, true]) {
    testWidgets('management shows only permitted actions (admin: $admin)', (
      tester,
    ) async {
      final service = SharedService(AppDatabase.instance)
        ..identity = {
          'group_id': 'g',
          'account': {
            'id': 'me',
            'roles': admin ? ['ADMIN', 'MEMBER'] : ['MEMBER'],
          },
        }
        ..snapshot = {
          'name': 'Notre groupe',
          'documents': <String, dynamic>{},
          'accounts': [
            {
              'id': 'me',
              'username': 'gestionnaire',
              'roles': ['ADMIN', 'MEMBER'],
              'shared': false,
            },
          ],
        };
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedServiceProvider.overrideWithValue(service)],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const SharedGroupScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Notre groupe'), findsOneWidget);
      expect(
        find.text('Comptes et rôles'),
        admin ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Ajouter un gestionnaire'),
        admin ? findsOneWidget : findsNothing,
      );
      expect(find.text('Arbitrages'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
