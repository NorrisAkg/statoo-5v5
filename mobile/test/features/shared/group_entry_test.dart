import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/core/router/app_router.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/onboarding/application/onboarding_provider.dart';
import 'package:statoo/features/players/application/players_provider.dart';
import 'package:statoo/features/players/domain/player.dart';
import 'package:statoo/features/shared/application/shared_providers.dart';
import 'package:statoo/features/shared/data/shared_service.dart';
import 'package:statoo/features/shared/presentation/shared_group_screen.dart';
import 'package:statoo/features/team/application/team_provider.dart';
import 'package:statoo/features/team/domain/team_info.dart';
import 'package:statoo/features/team/presentation/add_team_players_screen.dart';
import 'package:statoo/features/team/presentation/create_team_screen.dart';
import 'package:statoo/main.dart';

class _SetupPlayers extends PlayersNotifier {
  @override
  Future<List<Player>> build() async => [
    Player(
      id: 'alice',
      teamId: 'g',
      name: 'Alice',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ];
}

class _EmptyTeam extends TeamInfoNotifier {
  @override
  Future<TeamInfo?> build() async => null;
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });
  Future<ProviderContainer> mount(
    WidgetTester tester, {
    bool seen = true,
    bool team = false,
    SharedService? service,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hasSeenOnboardingProvider.overrideWith(
            () => OnboardingNotifier(initialValue: seen),
          ),
          hasTeamProvider.overrideWith(
            () => HasTeamNotifier(initialValue: team),
          ),
          if (service != null) sharedServiceProvider.overrideWithValue(service),
          playersListProvider.overrideWith(_SetupPlayers.new),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 500));
    return ProviderScope.containerOf(tester.element(find.byType(MyApp)));
  }

  for (final finish in [false, true]) {
    testWidgets('ORD01/02 onboarding then welcome finish=$finish', (
      tester,
    ) async {
      final c = await mount(tester, seen: false);
      expect(find.text('Suivez vos matchs 5v5'), findsOneWidget);
      expect(find.text('Créer un groupe'), findsNothing);
      if (finish) {
        for (var i = 0; i < 2; i++) {
          await tester.tap(find.text('Suivant'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
        }
      }
      await tester.tap(find.text(finish ? 'Commencer' : 'Passer'));
      await tester.pumpAndSettle();
      expect(find.text('Créer un groupe'), findsOneWidget);
      expect(find.text('Rejoindre un groupe'), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getBool('hasSeenOnboarding'),
        isTrue,
      );
      c.read(appRouterProvider).go('/splash');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pumpAndSettle();
      expect(find.text('Créer un groupe'), findsOneWidget);
      expect(find.text('Suivez vos matchs 5v5'), findsNothing);
    });
  }
  for (final path in [
    '/bienvenue',
    '/groupe-partage?installation=1',
    '/creer-equipe?partage=1',
  ]) {
    testWidgets('ORD03 first visit guards $path', (tester) async {
      final c = await mount(tester, seen: false);
      c.read(appRouterProvider).go(path);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Suivez vos matchs 5v5'), findsOneWidget);
      expect(c.read(hasSeenOnboardingProvider), isFalse);
    });
  }
  for (final seen in [false, true]) {
    testWidgets('ENT01/03 entry and direct join seen=$seen', (tester) async {
      final c = await mount(tester, seen: seen);
      if (!seen) {
        expect(find.text('Suivez vos matchs 5v5'), findsOneWidget);
        await tester.tap(find.text('Passer'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Créer un groupe'), findsOneWidget);
      expect(find.text('Rejoindre un groupe'), findsOneWidget);
      await tester.tap(find.text('Rejoindre un groupe'));
      await tester.pumpAndSettle();
      expect(find.text('Identifiant du groupe'), findsOneWidget);
      expect(find.text('Créer votre accès Admin'), findsNothing);
      expect(
        tester.widget<SharedGroupScreen>(find.byType(SharedGroupScreen)).setup,
        true,
      );
      expect(
        c
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .queryParameters['installation'],
        '1',
      );
    });
    testWidgets('ENT02 create preserves setup intent seen=$seen', (
      tester,
    ) async {
      await mount(tester, seen: seen);
      if (!seen) {
        await tester.tap(find.text('Passer'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Créer un groupe'));
      await tester.pumpAndSettle();
      expect(find.text('Créez votre équipe'), findsOneWidget);
      expect(
        tester
            .widget<CreateTeamScreen>(find.byType(CreateTeamScreen))
            .setupShared,
        true,
      );
    });
  }
  testWidgets('ENT04 direct setup explains Admin and later responsibilities', (
    tester,
  ) async {
    final c = await mount(tester);
    c.read(appRouterProvider).go('/groupe-partage?creation=1&installation=1');
    await tester.pumpAndSettle();
    expect(find.text('Créer votre accès Admin'), findsOneWidget);
    expect(
      find.textContaining('Ensuite, désignez les responsables'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Continuer sur cet appareil'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(SharedGroupScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Continuer sur cet appareil'), findsOneWidget);
    expect(find.text('Serveur'), findsNothing);
  });
  testWidgets('ENT03 direct join can return to entry after reload', (
    tester,
  ) async {
    final c = await mount(tester);
    c.read(appRouterProvider).go('/groupe-partage?installation=1');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Retour'), findsOneWidget);
    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    expect(find.text('Créer un groupe'), findsOneWidget);
  });
  for (final admin in [false, true]) {
    testWidgets('ENT05/09 responsibilities Admin only admin=$admin', (
      tester,
    ) async {
      final service = SharedService(AppDatabase.instance)
        ..identity = {
          'group_id': 'g',
          'account': {
            'id': 'me',
            'roles': [if (admin) 'ADMIN' else 'MEMBER'],
          },
        }
        ..snapshot = {
          'name': 'Mon groupe',
          'documents': <String, dynamic>{},
          'accounts': <dynamic>[],
        };
      addTearDown(service.dispose);
      final c = await mount(tester, team: true, service: service);
      c.read(appRouterProvider).go('/groupe-partage?creation=1&installation=1');
      await tester.pumpAndSettle();
      expect(
        find.text('Désigner les responsables'),
        admin ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Ajouter un gestionnaire'),
        admin ? findsOneWidget : findsNothing,
      );
      if (admin) {
        await tester.tap(find.text('Ajouter un gestionnaire'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        expect(find.text('Alice'), findsOneWidget);
        await tester.tap(find.text('Alice'));
        await tester.pumpAndSettle();
        expect(find.text('Président'), findsOneWidget);
        expect(find.text('Trésorier'), findsOneWidget);
        await tester.tap(find.text('Annuler'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Plus tard'));
        await tester.pumpAndSettle();
        expect(
          c.read(appRouterProvider).routeInformationProvider.value.uri.path,
          '/',
        );
      }
    });
  }
  for (final width in [320.0, 393.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets('ENT10 entry $width scale=$scale dark=$dark', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 700);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          tester.platformDispatcher.platformBrightnessTestValue = dark
              ? Brightness.dark
              : Brightness.light;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          addTearDown(
            tester.platformDispatcher.clearPlatformBrightnessTestValue,
          );
          await mount(tester);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  testWidgets(
    'ENT05 first responsibilities screen loads members without home',
    (tester) async {
      final service = SharedService(AppDatabase.instance)
        ..identity = {
          'group_id': 'g',
          'account': {
            'id': 'me',
            'roles': ['ADMIN'],
          },
        }
        ..snapshot = {
          'name': 'Mon groupe',
          'documents': <String, dynamic>{},
          'accounts': <dynamic>[],
        };
      addTearDown(service.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedServiceProvider.overrideWithValue(service),
            playersListProvider.overrideWith(_SetupPlayers.new),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SharedGroupScreen(initialCreate: true, setup: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajouter un gestionnaire'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text('Alice'), findsOneWidget);
    },
  );
  testWidgets('ENT10 shared password has a distinct accessible label', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(838, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SharedGroupScreen(initialCreate: true, setup: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.byType(TextField).last).label,
      contains('Mot de passe commun'),
    );
    semantics.dispose();
  });
  testWidgets('ENT10 effectif setup button fits 320 at 200 percent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playersListProvider.overrideWith(_SetupPlayers.new),
          teamInfoProvider.overrideWith(_EmptyTeam.new),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const AddTeamPlayersScreen(setupShared: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
