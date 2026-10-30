import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/players/application/players_provider.dart';
import 'package:statoo/features/players/data/players_repository.dart';
import 'package:statoo/features/players/domain/player.dart';
import 'package:statoo/features/players/domain/player_detail_data.dart';
import 'package:statoo/features/players/presentation/player_detail_screen.dart';
import 'package:statoo/features/team/application/team_provider.dart';
import 'package:statoo/features/team/data/team_repository.dart';
import 'package:statoo/features/team/domain/team_info.dart';

class _FakeTeamRepository implements TeamRepository {
  _FakeTeamRepository(this._activeTeam);
  final TeamInfo? _activeTeam;

  @override
  Future<TeamInfo?> getActiveTeam() async => _activeTeam;

  @override
  Future<String?> getActiveTeamId() async => _activeTeam?.id;

  @override
  Future<TeamInfo?> getTeamById(String id) async => _activeTeam?.id == id ? _activeTeam : null;

  @override
  Future<TeamInfo?> getTeamInfo() async => _activeTeam;

  @override
  Future<List<TeamInfo>> getAllTeams() async => _activeTeam != null ? [_activeTeam] : [];

  @override
  Future<void> setActiveTeamId(String id) async {}

  @override
  Future<void> saveTeamInfo(TeamInfo team) async {}

  @override
  Future<void> deleteTeam(String id) async {}

  @override
  Future<Map<String, int>> getTeamCounts(String teamId) async => {'players': 1, 'sessions': 0};
}

class _FakePlayersRepository implements PlayersRepository {
  _FakePlayersRepository(this.player);
  final Player player;

  @override
  Future<List<Player>> getPlayers({String? teamId}) async => [player];

  @override
  Future<Player?> getPlayer(String id, {required String teamId}) async {
    if (id == player.id && teamId == player.teamId) {
      return player;
    }
    return null;
  }

  @override
  Future<PlayerDetailStats> getPlayerStats(String id, {required String teamId}) async =>
      const PlayerDetailStats.empty();

  @override
  Future<List<PlayerMatchHistoryItem>> getPlayerMatchHistory(String id, {required String teamId}) async =>
      const [];

  @override
  Future<bool> canDeletePlayer(String id, {required String teamId}) async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  final now = DateTime(2026);
  final testPlayer = Player(
    id: 'p_test',
    name: 'Karim Benzema',
    nickname: 'KB9',
    teamId: 'team_test',
    createdAt: now,
    updatedAt: now,
  );

  testWidgets('PlayerDetailScreen resolves active team and displays player when activeTeamIdProvider starts uninitialized (page refresh scenario)', (tester) async {
    final teamRepo = _FakeTeamRepository(
      TeamInfo(
        id: 'team_test',
        name: 'Mon Équipe',
        createdAt: now,
      ),
    );
    final playersRepo = _FakePlayersRepository(testPlayer);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          teamRepositoryProvider.overrideWithValue(teamRepo),
          playersRepositoryProvider.overrideWithValue(playersRepo),
          activeTeamIdProvider.overrideWith(ActiveTeamIdNotifier.new),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('fr', 'FR')],
          home: const PlayerDetailScreen(playerId: 'p_test'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Must NOT display "Ce joueur n'existe pas ou a été supprimé."
    expect(find.text("Ce joueur n'existe pas ou a été supprimé."), findsNothing);
    // Must display player info
    expect(find.text('Karim Benzema'), findsWidgets);
  });
}
