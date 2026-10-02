import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/ranking/application/ranking_providers.dart';
import 'package:statoo/features/ranking/domain/mvp_entry.dart';
import 'package:statoo/features/ranking/presentation/standings_screen.dart';

void main() {
  group('StandingsScreen MVP Tab and Month Filter', () {
    testWidgets('renders all 6 tabs including MVP and navigates to MVP view', (tester) async {
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

      // Check all 6 tabs exist
      expect(find.text('Points'), findsOneWidget);
      expect(find.text('Pts / Match'), findsOneWidget);
      expect(find.text('Buteurs'), findsOneWidget);
      expect(find.text('Passeurs'), findsOneWidget);
      expect(find.text('Cartons'), findsOneWidget);
      expect(find.text('MVP'), findsOneWidget);

      // Check Month filter chips are displayed
      expect(find.text('Général'), findsOneWidget);

      // Navigate to MVP tab
      await tester.tap(find.text('MVP'));
      await tester.pumpAndSettle();

      // Verify Karim is displayed as Joueur du mois (Rank 1 eligible)
      expect(find.text('Karim'), findsOneWidget);
      expect(find.text('« Kaka »'), findsOneWidget);
      expect(find.textContaining('11.33'), findsOneWidget);
      expect(find.text('Joueur du mois'), findsOneWidget);

      // Verify Sofiane is displayed with Non éligible badge
      expect(find.text('Sofiane'), findsOneWidget);
      expect(find.textContaining('Non éligible'), findsOneWidget);
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

      await tester.tap(find.text('MVP'));
      await tester.pumpAndSettle();

      expect(find.text('Aucune donnée MVP pour cette période'), findsOneWidget);
    });
  });
}
