import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/core/widgets/initial_avatar.dart';
import 'package:statoo/features/players/application/players_provider.dart';
import 'package:statoo/features/players/data/players_repository.dart';
import 'package:statoo/features/players/domain/player.dart';
import 'package:statoo/features/players/domain/player_detail_data.dart';
import 'package:statoo/features/players/presentation/players_screen.dart';
import 'package:statoo/features/ranking/application/ranking_providers.dart';
import 'package:statoo/features/ranking/domain/standing_entry.dart';
import 'package:statoo/features/team/application/team_provider.dart';

class _FakePlayersRepository implements PlayersRepository {
  _FakePlayersRepository(this._players);

  final List<Player> _players;

  @override
  Future<List<Player>> getPlayers({String? teamId}) async => List.unmodifiable(_players);

  @override
  Future<Player?> getPlayer(String id, {required String teamId}) async =>
      _players.cast<Player?>().firstWhere((p) => p?.id == id, orElse: () => null);

  @override
  Future<PlayerDetailStats> getPlayerStats(String id, {required String teamId}) async => const PlayerDetailStats.empty();

  @override
  Future<List<PlayerMatchHistoryItem>> getPlayerMatchHistory(String id, {required String teamId}) async => const [];

  @override
  Future<Player> createPlayer({
    required String name,
    String? nickname,
    String? avatarUrl,
    String? teamId,
  }) async => throw UnimplementedError();

  @override
  Future<void> updatePlayer({
    required String teamId,
    required String id,
    required String name,
    String? nickname,
  }) async {}

  @override
  Future<void> togglePlayerActive({required String teamId, required String id, required bool isActive}) async {}

  @override
  Future<void> deletePlayer(String id, {required String teamId}) async {}

  @override
  Future<bool> canDeletePlayer(String id, {required String teamId}) async => id == 'p_3';

  @override
  Future<Set<String>> getDeletablePlayerIds({required String teamId}) async => {'p_3'};

  @override
  Future<bool> isNameTaken({
    required String name,
    String? teamId,
    String? excludePlayerId,
  }) async {
    final cleanName = name.trim().toLowerCase();
    return _players.any(
      (p) =>
          (teamId == null || p.teamId == teamId) &&
          (excludePlayerId == null || p.id != excludePlayerId) &&
          p.name.trim().toLowerCase() == cleanName,
    );
  }
}

void main() {
  test('InitialAvatar.colorForName produces deterministic colors', () {
    final color1 = InitialAvatar.colorForName('Karim');
    final color2 = InitialAvatar.colorForName('Karim');
    final colorOther = InitialAvatar.colorForName('Zinedine');

    expect(color1, equals(color2));
    expect(color1, isNotNull);
    expect(colorOther, isNotNull);
  });

  testWidgets('PlayersScreen filters players by name and nickname', (tester) async {
    final now = DateTime.now();
    final players = [
      Player(id: 'p_1', teamId: 't_1', name: 'Karim Benzema', nickname: 'KB9', createdAt: now, updatedAt: now),
      Player(id: 'p_2', teamId: 't_1', name: 'Zinedine Zidane', nickname: 'Zizou', createdAt: now, updatedAt: now),
      Player(id: 'p_3', teamId: 't_1', name: 'Luka Modric', createdAt: now, updatedAt: now),
    ];

    final standings = [
      const StandingEntry(
        rank: 1,
        playerId: 'p_1',
        name: 'Karim Benzema',
        isActive: true,
        matchesPlayed: 7,
        wins: 5,
        draws: 1,
        losses: 1,
        points: 16,
        goals: 12,
        assists: 4,
      ),
      const StandingEntry(
        rank: 2,
        playerId: 'p_2',
        name: 'Zinedine Zidane',
        isActive: true,
        matchesPlayed: 4,
        wins: 3,
        draws: 0,
        losses: 1,
        points: 9,
        goals: 5,
        assists: 8,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeTeamIdProvider.overrideWith(() => ActiveTeamIdNotifier(initialValue: 't_1')),
          playersRepositoryProvider.overrideWithValue(_FakePlayersRepository(players)),
          standingsProvider.overrideWith((ref) => Future.value(standings)),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const PlayersScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // All 3 players initially shown
    expect(find.text('Karim Benzema'), findsOneWidget);
    expect(find.text('Zinedine Zidane'), findsOneWidget);
    expect(find.text('Luka Modric'), findsOneWidget);

    // p_1 has stats: J 7 · 16 pts
    expect(find.text('J 7 · 16 pts'), findsOneWidget);
    // p_2 has stats: J 4 · 9 pts
    expect(find.text('J 4 · 9 pts'), findsOneWidget);

    // Filter by name "Zinedine"
    await tester.enterText(find.byType(TextField), 'Zinedine');
    await tester.pumpAndSettle();

    expect(find.text('Zinedine Zidane'), findsOneWidget);
    expect(find.text('Karim Benzema'), findsNothing);
    expect(find.text('Luka Modric'), findsNothing);

    // Filter by nickname "KB9"
    await tester.enterText(find.byType(TextField), 'KB9');
    await tester.pumpAndSettle();

    expect(find.text('Karim Benzema'), findsOneWidget);
    expect(find.text('Zinedine Zidane'), findsNothing);

    // Clear search using the suffix clear button
    await tester.tap(find.byIcon(Remix.close_circle_fill));
    await tester.pumpAndSettle();

    expect(find.text('Karim Benzema'), findsOneWidget);
    expect(find.text('Zinedine Zidane'), findsOneWidget);
    expect(find.text('Luka Modric'), findsOneWidget);
  });
}
