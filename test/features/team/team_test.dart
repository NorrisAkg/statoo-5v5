import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/players/application/players_provider.dart';
import 'package:statoo/features/players/data/players_repository.dart';
import 'package:statoo/features/players/domain/player.dart';
import 'package:statoo/features/team/application/team_provider.dart';
import 'package:statoo/features/team/data/team_repository.dart';
import 'package:statoo/features/team/domain/team_info.dart';
import 'package:statoo/features/team/presentation/add_team_players_screen.dart';
import 'package:statoo/features/team/presentation/create_team_screen.dart';

class _MockTeamRepository implements TeamRepository {
  TeamInfo? _team;

  @override
  Future<TeamInfo?> getTeamInfo() async => _team;

  @override
  Future<void> saveTeamInfo(TeamInfo team) async {
    _team = team;
  }
}

class _MockPlayersRepository implements PlayersRepository {
  final List<Player> _players = [];

  @override
  Future<List<Player>> getPlayers() async => List.unmodifiable(_players);

  @override
  Future<Player> createPlayer({
    required String name,
    String? nickname,
    String? avatarUrl,
  }) async {
    final now = DateTime.now();
    final player = Player(
      id: 'p_${_players.length + 1}',
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
  Future<void> deletePlayer(String id) async {
    _players.removeWhere((p) => p.id == id);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TeamInfo domain model', () {
    test('serializes and deserializes correctly', () {
      const team = TeamInfo(
        name: 'FC Urban',
        format: '7v7',
        location: 'Urban Soccer',
      );

      final map = team.toMap();
      expect(map['name'], 'FC Urban');
      expect(map['format'], '7v7');
      expect(map['location'], 'Urban Soccer');

      final parsed = TeamInfo.fromMap(map);
      expect(parsed.name, 'FC Urban');
      expect(parsed.format, '7v7');
      expect(parsed.location, 'Urban Soccer');
    });
  });

  group('CreateTeamScreen', () {
    testWidgets('renders form fields and validates team name', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final teamRepo = _MockTeamRepository();
      final router = GoRouter(
        initialLocation: '/creer-equipe',
        routes: [
          GoRoute(
            path: '/creer-equipe',
            builder: (context, state) => const CreateTeamScreen(),
          ),
          GoRoute(
            path: '/ajouter-joueurs-initiaux',
            builder: (context, state) => const Scaffold(body: Text('Écran joueurs')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            teamRepositoryProvider.overrideWithValue(teamRepo),
          ],
          child: MaterialApp.router(
            theme: AppTheme.darkTheme,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Créez votre équipe'), findsOneWidget);
      expect(find.text("Nom de l'équipe ou du groupe *"), findsOneWidget);
      expect(find.text('Format de jeu habituel'), findsOneWidget);
      expect(find.text("Continuer vers l'effectif"), findsOneWidget);

      // Tap submit with empty name
      await tester.tap(find.text("Continuer vers l'effectif"));
      await tester.pumpAndSettle();

      expect(find.text('Veuillez renseigner le nom de votre équipe'), findsOneWidget);

      // Enter name and select 6v6 format
      await tester.enterText(find.byType(TextFormField).first, 'Les Invincibles');
      await tester.tap(find.text('6v6'));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Continuer vers l'effectif"));
      await tester.pumpAndSettle();

      final saved = await teamRepo.getTeamInfo();
      expect(saved?.name, 'Les Invincibles');
      expect(saved?.format, '6v6');
    });
  });

  group('AddTeamPlayersScreen', () {
    testWidgets('renders player input form and allows adding players', (tester) async {
      final playersRepo = _MockPlayersRepository();
      final teamRepo = _MockTeamRepository();
      await teamRepo.saveTeamInfo(const TeamInfo(name: 'FC Urban'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            teamRepositoryProvider.overrideWithValue(teamRepo),
            playersRepositoryProvider.overrideWithValue(playersRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const AddTeamPlayersScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ajoutez vos joueurs'), findsOneWidget);
      expect(find.text('FC Urban'), findsOneWidget);
      expect(find.text('EFFECTIF ACTUEL (0)'), findsOneWidget);

      // Add a player
      await tester.enterText(find.byType(TextFormField).first, 'Lucas');
      await tester.enterText(find.byType(TextFormField).at(1), 'Lulu');
      await tester.tap(find.text('Ajouter ce joueur'));
      await tester.pumpAndSettle();

      expect(find.text('EFFECTIF ACTUEL (1)'), findsOneWidget);
      expect(find.text('Lucas'), findsOneWidget);
      expect(find.text('« Lulu »'), findsOneWidget);

      // Add a second player
      await tester.enterText(find.byType(TextFormField).first, 'Karim');
      await tester.tap(find.text('Ajouter ce joueur'));
      await tester.pumpAndSettle();

      expect(find.text('EFFECTIF ACTUEL (2)'), findsOneWidget);
      expect(find.text('Karim'), findsOneWidget);
    });
  });
}
