import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/app_database.dart';
import '../data/players_repository.dart';
import '../domain/player.dart';

final playersRepositoryProvider = Provider<PlayersRepository>((ref) {
  return SqlitePlayersRepository(AppDatabase.instance);
});

class PlayersNotifier extends AsyncNotifier<List<Player>> {
  @override
  Future<List<Player>> build() => ref.watch(playersRepositoryProvider).getPlayers();

  Future<Player> addPlayer({
    required String name,
    String? nickname,
    String? avatarUrl,
  }) async {
    final player = await ref.read(playersRepositoryProvider).createPlayer(
      name: name,
      nickname: nickname,
      avatarUrl: avatarUrl,
    );
    ref.invalidateSelf();
    return player;
  }

  Future<void> removePlayer(String id) async {
    await ref.read(playersRepositoryProvider).deletePlayer(id);
    ref.invalidateSelf();
  }
}

final playersListProvider = AsyncNotifierProvider<PlayersNotifier, List<Player>>(
  PlayersNotifier.new,
);
