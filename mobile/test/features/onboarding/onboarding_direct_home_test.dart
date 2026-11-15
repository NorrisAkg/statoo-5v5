import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/onboarding/presentation/group_entry_screen.dart';
import 'package:statoo/features/players/application/players_provider.dart';
import 'package:statoo/features/players/domain/player.dart';
import 'package:statoo/features/team/application/team_provider.dart';
import 'package:statoo/features/team/domain/team_info.dart';
import 'package:statoo/features/team/presentation/add_team_players_screen.dart';

class _FakeTeamInfoNotifier extends TeamInfoNotifier {
  @override
  Future<TeamInfo?> build() async => const TeamInfo(id: 't1', name: 'FC Test');
}

class _FakePlayersNotifier extends PlayersNotifier {
  @override
  Future<List<Player>> build() async => [
    Player(id: 'p1', teamId: 't1', name: 'Alice', createdAt: DateTime(2026), updatedAt: DateTime(2026)),
    Player(id: 'p2', teamId: 't1', name: 'Bob', createdAt: DateTime(2026), updatedAt: DateTime(2026)),
  ];
}

void main() {
  testWidgets('GroupEntryScreen: Créer un groupe navigue vers /creer-equipe sans ?partage=1', (tester) async {
    String? navigatedTo;
    final router = GoRouter(
      initialLocation: '/entree-groupe',
      routes: [
        GoRoute(
          path: '/entree-groupe',
          builder: (_, _) => const GroupEntryScreen(),
        ),
        GoRoute(
          path: '/creer-equipe',
          builder: (_, state) {
            navigatedTo = state.uri.toString();
            return const Scaffold(body: Text('CREATE_TEAM'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Créer un groupe'));
    await tester.pumpAndSettle();

    expect(navigatedTo, '/creer-equipe');
  });

  testWidgets('AddTeamPlayersScreen: terminer navigue directement vers / (accueil)', (tester) async {
    String? navigatedTo;
    final router = GoRouter(
      initialLocation: '/ajouter-joueurs-initiaux',
      routes: [
        GoRoute(
          path: '/ajouter-joueurs-initiaux',
          builder: (_, _) => const AddTeamPlayersScreen(setupShared: true),
        ),
        GoRoute(
          path: '/',
          builder: (_, state) {
            navigatedTo = state.uri.toString();
            return const Scaffold(body: Text('HOME'));
          },
        ),
        GoRoute(
          path: '/groupe-partage',
          builder: (_, state) {
            navigatedTo = state.uri.toString();
            return const Scaffold(body: Text('SHARED_GROUP'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          teamInfoProvider.overrideWith(_FakeTeamInfoNotifier.new),
          playersListProvider.overrideWith(_FakePlayersNotifier.new),
        ],
        child: MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ElevatedButton).last);
    await tester.pumpAndSettle();

    expect(navigatedTo, '/');
  });
}
