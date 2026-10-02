import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/core/widgets/app_card.dart';
import 'package:statoo/features/home/presentation/home_screen.dart';
import 'package:statoo/features/players/application/players_provider.dart';
import 'package:statoo/features/players/domain/player.dart';
import 'package:statoo/features/sessions/application/sessions_provider.dart';
import 'package:statoo/features/sessions/domain/session.dart';
import 'package:statoo/features/sessions/domain/session_summary.dart';
import 'package:statoo/features/stats/application/stats_providers.dart';
import 'package:statoo/features/stats/domain/group_totals.dart';

class _MockPlayersNotifier extends PlayersNotifier {
  _MockPlayersNotifier(this._players);
  final List<Player> _players;

  @override
  Future<List<Player>> build() async => _players;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
  });

  group('HomeScreen Tiles', () {
    testWidgets('displays correct values for Joueurs, Séances and Stats tiles', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final mockPlayers = [
        Player(
          id: 'p1',
          teamId: 'team_1',
          name: 'Lucas',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Player(
          id: 'p2',
          teamId: 'team_1',
          name: 'Karim',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final mockSessions = [
        SessionSummaryItem(
          session: Session(
            id: 's1',
            playedAt: DateTime.now(),
            status: SessionStatus.closed,
            isRanked: true,
            scoreA: 5,
            scoreB: 3,
          ),
          playerCount: 10,
        ),
        SessionSummaryItem(
          session: Session(
            id: 's2',
            playedAt: DateTime.now(),
            status: SessionStatus.closed,
            isRanked: true,
            scoreA: 4,
            scoreB: 2,
          ),
          playerCount: 10,
        ),
        SessionSummaryItem(
          session: Session(
            id: 's3',
            playedAt: DateTime.now(),
            status: SessionStatus.closed,
            isRanked: true,
            scoreA: 3,
            scoreB: 1,
          ),
          playerCount: 10,
        ),
      ];

      const mockTotals = GroupTotals(
        totalSessions: 3,
        rankedSessions: 3,
        friendlySessions: 0,
        totalPlayers: 2,
        activePlayers: 2,
        totalGoals: 18,
        avgGoalsPerSession: 6,
        totalAssists: 12,
        totalYellowCards: 1,
        totalRedCards: 0,
        totalPlayerGoals: 18,
        unassignedGoalsDifference: 0,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playersListProvider.overrideWith(() => _MockPlayersNotifier(mockPlayers)),
            sessionsListProvider.overrideWith((ref) => Future.value(mockSessions)),
            groupTotalsProvider.overrideWith((ref) => Future.value(mockTotals)),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Joueurs tile
      final joueursTile = find.ancestor(of: find.text('Joueurs'), matching: find.byType(AppCard));
      expect(find.descendant(of: joueursTile, matching: find.text('2')), findsOneWidget);

      // Check Séances tile
      final seancesTile = find.ancestor(of: find.text('Séances'), matching: find.byType(AppCard));
      expect(find.descendant(of: seancesTile, matching: find.text('3')), findsOneWidget);

      // Check Stats tile: must display total goals and assists "18 B · 12 P" instead of "-"
      final statsTile = find.ancestor(of: find.text('Stats'), matching: find.byType(AppCard));
      expect(find.descendant(of: statsTile, matching: find.text('18 B · 12 P')), findsOneWidget);
      expect(find.descendant(of: statsTile, matching: find.text('-')), findsNothing);
    });
  });
}
