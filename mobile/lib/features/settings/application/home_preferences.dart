import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final showPlayerOfMonthProvider = AsyncNotifierProvider<HomePreferences, bool>(
  HomePreferences.new,
);

class HomePreferences extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async =>
      (await SharedPreferences.getInstance()).getBool('show_player_of_month') ??
      true;
  Future<void> setVisible(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setBool('show_player_of_month', value);
    if (!saved) throw StateError('Préférence non enregistrée. Réessayez.');
    if (ref.mounted) state = AsyncData(value);
  }
}
