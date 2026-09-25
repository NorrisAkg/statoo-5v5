import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/app_database.dart';
import '../../ranking/application/ranking_providers.dart';
import '../../stats/application/stats_providers.dart';
import '../../team/application/team_provider.dart';
import '../data/players_repository.dart';
import '../domain/player.dart';
import '../domain/player_detail_data.dart';

final Provider<PlayersRepository> playersRepositoryProvider = Provider<PlayersRepository>((ref) {
  return SqlitePlayersRepository(AppDatabase.instance);
});

class PlayersNotifier extends AsyncNotifier<List<Player>> {
  @override
  Future<List<Player>> build() {
    final activeTeam = ref.watch(activeTeamProvider).value;
    return ref.watch(playersRepositoryProvider).getPlayers(teamId: activeTeam?.id);
  }

  Future<Player> addPlayer({
    required String name,
    String? nickname,
    String? avatarUrl,
  }) async {
    final activeTeam = ref.read(activeTeamProvider).value;
    final player = await ref.read(playersRepositoryProvider).createPlayer(
      name: name,
      nickname: nickname,
      avatarUrl: avatarUrl,
      teamId: activeTeam?.id,
    );
    final currentList = state.value;
    if (currentList != null) {
      state = AsyncData([...currentList, player]);
    }
    _invalidateAll(player.id);
    return player;
  }

  Future<void> updatePlayer({
    required String id,
    required String name,
    String? nickname,
  }) async {
    await ref.read(playersRepositoryProvider).updatePlayer(
      id: id,
      name: name,
      nickname: nickname,
    );
    final currentList = state.value;
    if (currentList != null) {
      state = AsyncData(
        currentList.map((p) {
          if (p.id == id) {
            return p.copyWith(
              name: name.trim(),
              nickname: (nickname != null && nickname.trim().isNotEmpty) ? nickname.trim() : null,
              updatedAt: DateTime.now(),
            );
          }
          return p;
        }).toList(),
      );
    }
    _invalidateAll(id);
  }

  Future<void> togglePlayerActive({required String id, required bool isActive}) async {
    await ref.read(playersRepositoryProvider).togglePlayerActive(id: id, isActive: isActive);
    final currentList = state.value;
    if (currentList != null) {
      state = AsyncData(
        currentList.map((p) {
          if (p.id == id) {
            return p.copyWith(
              isActive: isActive,
              updatedAt: DateTime.now(),
            );
          }
          return p;
        }).toList(),
      );
    }
    _invalidateAll(id);
  }

  Future<bool> removePlayer(String id) async {
    final canDelete = await ref.read(playersRepositoryProvider).canDeletePlayer(id);
    if (!canDelete) return false;
    await ref.read(playersRepositoryProvider).deletePlayer(id);
    final currentList = state.value;
    if (currentList != null) {
      state = AsyncData(
        currentList.where((p) => p.id != id).toList(),
      );
    }
    _invalidateAll(id);
    return true;
  }

  void _invalidateAll(String id) {
    ref
      ..invalidateSelf()
      ..invalidate(playerDetailProvider(id))
      ..invalidate(playerStatsProvider(id))
      ..invalidate(playerMatchHistoryProvider(id))
      ..invalidate(canDeletePlayerProvider(id))
      ..invalidate(deletablePlayerIdsProvider)
      ..invalidate(standingsProvider)
      ..invalidate(standingsPerMatchProvider)
      ..invalidate(topScorersProvider)
      ..invalidate(topAssistsProvider)
      ..invalidate(topCardsProvider)
      ..invalidate(groupTotalsProvider);
  }
}

final AsyncNotifierProvider<PlayersNotifier, List<Player>> playersListProvider =
    AsyncNotifierProvider<PlayersNotifier, List<Player>>(
  PlayersNotifier.new,
);

// Inferred Riverpod provider family type.
// ignore: specify_nonobvious_property_types
final playerDetailProvider = FutureProvider.family<Player?, String>((ref, playerId) async {
  final playersAsync = ref.watch(playersListProvider);
  final inMemory = playersAsync.value?.where((p) => p.id == playerId).firstOrNull;
  if (inMemory != null) return inMemory;
  return await ref.watch(playersRepositoryProvider).getPlayer(playerId);
});

// Inferred Riverpod provider family type.
// ignore: specify_nonobvious_property_types
final playerStatsProvider = FutureProvider.family<PlayerDetailStats, String>((ref, playerId) {
  return ref.watch(playersRepositoryProvider).getPlayerStats(playerId);
});

// Inferred Riverpod provider family type.
// ignore: specify_nonobvious_property_types
final playerMatchHistoryProvider =
    FutureProvider.family<List<PlayerMatchHistoryItem>, String>((ref, playerId) {
  return ref.watch(playersRepositoryProvider).getPlayerMatchHistory(playerId);
});

// Inferred Riverpod provider family type.
// ignore: specify_nonobvious_property_types
final canDeletePlayerProvider = FutureProvider.family<bool, String>((ref, playerId) {
  return ref.watch(playersRepositoryProvider).canDeletePlayer(playerId);
});

final FutureProvider<Set<String>> deletablePlayerIdsProvider =
    FutureProvider<Set<String>>((ref) {
  return ref.watch(playersRepositoryProvider).getDeletablePlayerIds();
});
