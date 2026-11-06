import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/players/application/players_provider.dart';
import 'package:statoo/features/players/domain/player.dart';
import 'package:statoo/features/team/application/team_provider.dart';
import 'package:statoo/features/team/domain/team_info.dart';
import 'package:statoo/features/team/presentation/add_team_players_screen.dart';

class _FakeTeam extends TeamInfoNotifier {
  _FakeTeam(this._team);
  final TeamInfo _team;
  @override
  Future<TeamInfo?> build() async => _team;
}

class FakePlayersNotifier extends PlayersNotifier {
  FakePlayersNotifier(this._players);
  final List<Player> _players;
  @override
  Future<List<Player>> build() async => _players;
}

void main() {
  final testTeam = TeamInfo(
    id: 'team_test',
    name: 'FC Test',
    createdAt: DateTime.now(),
  );

  final testPlayers = List.generate(
    15,
    (index) => Player(
      id: 'player_$index',
      teamId: 'team_test',
      name: 'Joueur $index',
      nickname: 'J$index',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  );

  testWidgets('AddTeamPlayersScreen liste de joueurs est bornee en hauteur et scrollable', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          teamInfoProvider.overrideWith(() => _FakeTeam(testTeam)),
          playersListProvider.overrideWith(() => FakePlayersNotifier(testPlayers)),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const AddTeamPlayersScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('EFFECTIF ACTUEL (15)'), findsOneWidget);

    final rosterContainerFinder = find.byKey(const ValueKey('team_players_roster_box'));
    expect(
      rosterContainerFinder,
      findsOneWidget,
      reason: 'La liste des joueurs doit être contrainte en hauteur (ex: maxHeight <= 300)',
    );

    final playerListFinder = find.byWidgetPredicate(
      (widget) =>
          widget is ListView &&
          widget.physics is! NeverScrollableScrollPhysics,
    );
    expect(
      playerListFinder,
      findsAtLeastNWidgets(1),
      reason: 'La liste des joueurs doit être défilante avec sa propre ScrollPhysics autonome',
    );
  });

  testWidgets('AddTeamPlayersScreen responsive sur petit ecran (320dp) et grand texte sans overflow', (tester) async {
    tester.view.physicalSize = const Size(320 * 2, 600 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          teamInfoProvider.overrideWith(() => _FakeTeam(testTeam)),
          playersListProvider.overrideWith(() => FakePlayersNotifier(testPlayers)),
        ],
        child: MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(1.4),
            size: Size(320, 600),
          ),
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const AddTeamPlayersScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Ajoutez vos joueurs'), findsOneWidget);
  });
}
