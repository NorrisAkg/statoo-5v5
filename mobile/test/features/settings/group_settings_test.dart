import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:statoo/features/settings/application/settings_provider.dart';
import 'package:statoo/features/settings/data/group_settings_repository.dart';
import 'package:statoo/features/team/application/team_provider.dart';
import 'package:statoo/features/shared/application/shared_providers.dart';

class _MemoryGroupSettings implements GroupSettingsRepository {
  final Map<String, int> store = {};

  @override
  Future<int?> getInt(String teamId, String key) async => store[groupSettingKey(key, teamId)];

  @override
  Future<void> setInt(String teamId, String key, int value) async {
    store[groupSettingKey(key, teamId)] = value;
  }
}

class _SwitchableTeam extends ActiveTeamIdNotifier {
  _SwitchableTeam(String initial) : super(initialValue: initial);

  // Test helper mimicking a team switch; a method keeps the call site explicit.
  // ignore: use_setters_to_change_properties
  void switchTo(String id) => state = id;
}

void main() {
  late _MemoryGroupSettings repo;
  late ProviderContainer container;

  ProviderContainer makeContainer({String team = 'team_1'}) {
    final c = ProviderContainer(
      overrides: [
        groupSettingsRepositoryProvider.overrideWithValue(repo),
        activeTeamIdProvider.overrideWith(() => _SwitchableTeam(team)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = _MemoryGroupSettings();
    container = makeContainer();
  });

  test('defaults apply when nothing is stored', () async {
    expect(container.read(minPlayersPerSessionProvider), kDefaultMinPlayers);
    expect(container.read(tournamentDrawPointsProvider), kDefaultTournamentDrawPoints);
  });

  test('values are saved per group and never leak to another group', () async {
    await container.read(minPlayersPerSessionProvider.notifier).setMinPlayers(10);
    await container.read(tournamentDrawPointsProvider.notifier).setDrawPoints(2);
    expect(repo.store, {
      'min_players_per_session_team_1': 10,
      'tournament_draw_points_team_1': 2,
    });

    (container.read(activeTeamIdProvider.notifier) as _SwitchableTeam).switchTo('team_2');
    expect(container.read(minPlayersPerSessionProvider), kDefaultMinPlayers);
    await settle();
    expect(container.read(minPlayersPerSessionProvider), kDefaultMinPlayers);
    expect(container.read(tournamentDrawPointsProvider), kDefaultTournamentDrawPoints);

    await container.read(minPlayersPerSessionProvider.notifier).setMinPlayers(4);
    (container.read(activeTeamIdProvider.notifier) as _SwitchableTeam).switchTo('team_1');
    // Providers rebuild lazily: reading them starts the load for the new group.
    container
      ..read(minPlayersPerSessionProvider)
      ..read(tournamentDrawPointsProvider);
    await settle();
    expect(container.read(minPlayersPerSessionProvider), 10);
    expect(container.read(tournamentDrawPointsProvider), 2);
    expect(repo.store['min_players_per_session_team_2'], 4);
  });

  test('legacy global preferences seed groups that have no value yet', () async {
    SharedPreferences.setMockInitialValues({kMinPlayersKey: 8, kTournamentDrawPointsKey: 2});
    final c = makeContainer();
    expect(c.read(minPlayersPerSessionProvider), kDefaultMinPlayers);
    expect(c.read(tournamentDrawPointsProvider), kDefaultTournamentDrawPoints);
    await settle();
    expect(c.read(minPlayersPerSessionProvider), 8);
    expect(c.read(tournamentDrawPointsProvider), 2);

    // A stored per-group value wins over the legacy one.
    repo.store['min_players_per_session_team_1'] = 5;
    await c.read(minPlayersPerSessionProvider.notifier).reload();
    expect(c.read(minPlayersPerSessionProvider), 5);
  });

  test('invalid values are rejected', () async {
    await container.read(minPlayersPerSessionProvider.notifier).setMinPlayers(1);
    await container.read(tournamentDrawPointsProvider.notifier).setDrawPoints(3);
    expect(repo.store, isEmpty);
  });

  test('FIX-06 shared minimum follows server updates and cannot be changed locally', () async {
    final service = container.read(sharedServiceProvider)
      ..identity = {'group_id': 'team_1', 'account': {'roles': ['ADMIN']}}
      ..snapshot = {'sport_settings': {'min_players_per_session': 8}};
    expect(container.read(minPlayersPerSessionProvider), 8);
    await container.read(minPlayersPerSessionProvider.notifier).setMinPlayers(4);
    expect(container.read(minPlayersPerSessionProvider), 8);
    expect(repo.store, isEmpty);
    service.snapshot = {'sport_settings': {'min_players_per_session': 10}};
    container.read(sharedStatusProvider.notifier).refresh();
    expect(container.read(minPlayersPerSessionProvider), 10);
    (container.read(activeTeamIdProvider.notifier) as _SwitchableTeam).switchTo('team_2');
    await container.read(minPlayersPerSessionProvider.notifier).setMinPlayers(4);
    expect(repo.store['min_players_per_session_team_2'], 4);
  });

  test('FIX-06b disconnected protected group cannot change its cached common minimum', () async {
    repo.store['min_players_per_session_team_1'] = 8;
    container.read(sharedServiceProvider).protectedGroups.add('team_1');
    container.read(minPlayersPerSessionProvider);
    await settle();
    expect(container.read(minPlayersPerSessionProvider), 8);
    await container.read(minPlayersPerSessionProvider.notifier).setMinPlayers(4);
    expect(repo.store['min_players_per_session_team_1'], 8);
  });
}
