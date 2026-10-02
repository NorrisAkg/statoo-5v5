import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/ranking/application/ranking_providers.dart';
import 'package:statoo/features/ranking/domain/mvp_entry.dart';
import 'package:statoo/features/ranking/presentation/standings_screen.dart';

void main() {
  group('StandingsScreen 2 View Modes (Championnat & MVP du mois)', () {
    testWidgets('renders Championship with 5 tabs and switches to MVP du mois view', (tester) async {
      final mockMvpList = [
        const MvpEntry(
          rank: 1,
          playerId: 'p2',
          name: 'Karim',
          nickname: 'Kaka',
          matchesPlayed: 3,
          totalSessions: 4,
          wins: 2,
          draws: 1,
          losses: 0,
          goals: 5,
          assists: 1,
          yellowCards: 0,
          redCards: 0,
          score: 11.33,
          isEligible: true,
          missingMatches: 0,
          month: '2026-10',
        ),
        const MvpEntry(
          rank: 2,
          playerId: 'p3',
          name: 'Sofiane',
          matchesPlayed: 1,
          totalSessions: 4,
          wins: 1,
          draws: 0,
          losses: 0,
          goals: 2,
          assists: 0,
          yellowCards: 0,
          redCards: 0,
          score: 14,
          isEligible: false,
          missingMatches: 2,
          month: '2026-10',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            availableRankingMonthsProvider.overrideWith((ref) => Future.value(['2026-10', '2026-09'])),
            monthlyMvpRankingProvider.overrideWith((ref) => Future.value(mockMvpList)),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const StandingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check mode switcher exists
      expect(find.text('Championnat'), findsOneWidget);
      expect(find.text('MVP du mois'), findsOneWidget);

      // In Championship mode, 5 tabs exist (NO 6th MVP tab in TabBar)
      expect(find.text('Points'), findsOneWidget);
      expect(find.text('Pts / Match'), findsOneWidget);
      expect(find.text('Buteurs'), findsOneWidget);
      expect(find.text('Passeurs'), findsOneWidget);
      expect(find.text('Cartons'), findsOneWidget);

      // Check Month filter chips are displayed
      expect(find.text('Général'), findsOneWidget);

      // Switch to MVP du mois mode
      await tester.tap(find.text('MVP du mois'));
      await tester.pumpAndSettle();

      // Verify Karim is displayed as Joueur du mois (Rank 1 eligible)
      expect(find.text('Karim'), findsOneWidget);
      expect(find.text('« Kaka »'), findsOneWidget);
      expect(find.textContaining('11.33'), findsWidgets);
      expect(find.textContaining('Joueur du mois'), findsWidgets);

      // Verify Sofiane is displayed with Non éligible badge
      expect(find.text('Sofiane'), findsOneWidget);
      expect(find.textContaining('Non éligible'), findsOneWidget);

      // Verify rules reminder exists
      expect(find.text('Règles MVP & Éligibilité'), findsOneWidget);
    });

    testWidgets('shows empty state when no matches in selected month', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            availableRankingMonthsProvider.overrideWith((ref) => Future.value(['2026-10'])),
            monthlyMvpRankingProvider.overrideWith((ref) => Future.value(const [])),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const StandingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on MVP du mois mode to switch view
      await tester.tap(find.text('MVP du mois'));
      await tester.pumpAndSettle();

      expect(find.text('Aucune donnée MVP pour cette période'), findsOneWidget);
    });
  });
}
