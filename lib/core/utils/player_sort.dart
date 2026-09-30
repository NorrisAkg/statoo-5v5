import '../../features/players/domain/player.dart';

/// Comparateur alphabétique insensible à la casse pour les joueurs.
///
/// Compare sur [Player.name] en minuscules.
int comparePlayersAlphabetically(Player a, Player b) {
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

/// Trie une liste de joueurs sur place :
/// 1. Les joueurs dont l'id est dans [selectedIds] en premier,
/// 2. puis par ordre alphabétique dans chaque groupe.
void sortPlayersSelectedFirst(
  List<Player> players, {
  required Set<String> selectedIds,
}) {
  players.sort((a, b) {
    final aSelected = selectedIds.contains(a.id);
    final bSelected = selectedIds.contains(b.id);
    if (aSelected != bSelected) return aSelected ? -1 : 1;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
}
