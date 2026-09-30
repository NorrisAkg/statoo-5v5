import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/players/application/players_provider.dart';
import 'package:statoo/features/players/data/players_repository.dart';
import 'package:statoo/features/players/domain/player.dart';
import 'package:statoo/features/players/domain/player_detail_data.dart';
import 'package:statoo/features/players/presentation/new_player_bottom_sheet.dart';
import 'package:statoo/features/team/application/team_provider.dart';

class _MockPlayersRepository implements PlayersRepository {
  final List<Player> _players = [];

  @override
  Future<List<Player>> getPlayers({String? teamId}) async =>
      List.unmodifiable(_players);

  @override
  Future<Player?> getPlayer(String id) async =>
      _players.cast<Player?>().firstWhere((p) => p?.id == id, orElse: () => null);

  @override
  Future<PlayerDetailStats> getPlayerStats(String id) async =>
      const PlayerDetailStats.empty();

  @override
  Future<List<PlayerMatchHistoryItem>> getPlayerMatchHistory(String id) async =>
      const [];

  @override
  Future<Player> createPlayer({
    required String name,
    String? nickname,
    String? avatarUrl,
    String? teamId,
  }) async {
    final now = DateTime.now();
    final player = Player(
      id: 'p_${_players.length + 1}',
      teamId: teamId ?? 'team_1',
      name: name,
      nickname: nickname,
      avatarUrl: avatarUrl,
      createdAt: now,
      updatedAt: now,
    );
    _players.add(player);
    return player;
  }

  @override
  Future<void> updatePlayer({
    required String id,
    required String name,
    String? nickname,
  }) async {}

  @override
  Future<void> togglePlayerActive({
    required String id,
    required bool isActive,
  }) async {}

  @override
  Future<bool> canDeletePlayer(String id) async => true;

  @override
  Future<Set<String>> getDeletablePlayerIds() async =>
      _players.map((p) => p.id).toSet();

  @override
  Future<void> deletePlayer(String id) async {
    _players.removeWhere((p) => p.id == id);
  }

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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('NewPlayerBottomSheet', () {
    testWidgets('refocuses name field after creating player with createAnother button', (tester) async {
      final repo = _MockPlayersRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playersRepositoryProvider.overrideWithValue(repo),
            activeTeamIdProvider.overrideWith(() => ActiveTeamIdNotifier(initialValue: 'team_1')),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: NewPlayerBottomSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final nameEditable = tester.widget<EditableText>(
        find.descendant(
          of: find.byType(TextField).first,
          matching: find.byType(EditableText),
        ),
      );
      // Autofocus is active on name field
      expect(nameEditable.focusNode.hasFocus, isTrue);

      // Enter player name and nickname
      await tester.enterText(find.byType(TextField).first, 'Antoine');
      await tester.enterText(find.byType(TextField).at(1), 'Anto');
      await tester.pumpAndSettle();

      // Tap create another button (+)
      await tester.tap(find.byIcon(Remix.add_line));
      await tester.pumpAndSettle();

      // Verify player added
      final players = await repo.getPlayers();
      expect(players.length, 1);
      expect(players.first.name, 'Antoine');

      // Verify name field is cleared and focus is returned
      expect(nameEditable.focusNode.hasFocus, isTrue);
    });

    testWidgets('shows inline error message when attempting to add duplicate player name', (tester) async {
      final repo = _MockPlayersRepository();
      await repo.createPlayer(name: 'Lucas', teamId: 'team_1');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playersRepositoryProvider.overrideWithValue(repo),
            activeTeamIdProvider.overrideWith(() => ActiveTeamIdNotifier(initialValue: 'team_1')),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: NewPlayerBottomSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'lucas');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Créer'));
      await tester.pumpAndSettle();

      expect(find.textContaining('existe déjà'), findsOneWidget);
    });
  });
}
