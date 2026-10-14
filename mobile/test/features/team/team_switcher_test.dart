import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/team/application/team_provider.dart';
import 'package:statoo/features/team/data/team_repository.dart';
import 'package:statoo/features/team/domain/team_info.dart';
import 'package:statoo/features/team/presentation/team_switcher_bottom_sheet.dart';

class _MockTeamRepository implements TeamRepository {
  _MockTeamRepository(List<TeamInfo> teams, {String? activeId}) {
    _teams.addAll(teams);
    if (activeId != null) {
      _activeTeam = _teams.cast<TeamInfo?>().firstWhere(
            (t) => t?.id == activeId,
            orElse: () => null,
          );
    } else if (teams.isNotEmpty) {
      _activeTeam = teams.first;
    }
  }

  TeamInfo? _activeTeam;
  final List<TeamInfo> _teams = [];

  @override
  Future<TeamInfo?> getTeamInfo() async => _activeTeam;

  @override
  Future<List<TeamInfo>> getAllTeams() async => List.unmodifiable(_teams);

  @override
  Future<TeamInfo?> getTeamById(String id) async =>
      _teams.cast<TeamInfo?>().firstWhere((t) => t?.id == id, orElse: () => null);

  @override
  Future<TeamInfo?> getActiveTeam() async => _activeTeam;

  @override
  Future<String?> getActiveTeamId() async => _activeTeam?.id;

  @override
  Future<void> setActiveTeamId(String id) async {
    _activeTeam =
        _teams.cast<TeamInfo?>().firstWhere((t) => t?.id == id, orElse: () => null);
  }

  @override
  Future<void> saveTeamInfo(TeamInfo team) async {
    _activeTeam = team;
    final idx = _teams.indexWhere((t) => t.id == team.id);
    if (idx >= 0) {
      _teams[idx] = team;
    } else {
      _teams.add(team);
    }
  }

  @override
  Future<void> deleteTeam(String id) async {
    _teams.removeWhere((t) => t.id == id);
    if (_activeTeam?.id == id) _activeTeam = null;
  }

  @override
  Future<Map<String, int>> getTeamCounts(String teamId) async => {
        'players': 5,
        'sessions': 2,
      };
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TeamSwitcherBottomSheet', () {
    testWidgets('renders all teams and highlights active team', (tester) async {
      const team1 = TeamInfo(id: 't_1', name: 'FC Urban');
      const team2 = TeamInfo(id: 't_2', name: 'Les Galactiques', format: '7v7');
      final repo = _MockTeamRepository([team1, team2], activeId: 't_1');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            teamRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showTeamSwitcher(context),
                  child: const Text('Open Switcher'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open bottom sheet
      await tester.tap(find.text('Open Switcher'));
      await tester.pumpAndSettle();

      expect(find.text('Vos groupes'), findsOneWidget);
      expect(find.text('FC Urban'), findsOneWidget);
      expect(find.text('Les Galactiques'), findsOneWidget);
      expect(find.text('Actif'), findsOneWidget);
      expect(find.text('Créer un nouveau groupe'), findsOneWidget);

      // Switch to team 2
      await tester.tap(find.text('Les Galactiques'));
      await tester.pumpAndSettle();

      expect(await repo.getActiveTeamId(), 't_2');
    });
  });
}
