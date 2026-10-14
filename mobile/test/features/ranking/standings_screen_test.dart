import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/ranking/application/ranking_providers.dart';
import 'package:statoo/features/ranking/domain/card_entry.dart';
import 'package:statoo/features/ranking/presentation/standings_screen.dart';

void main() {
  group('StandingsScreen Cartons tab', () {
    testWidgets('renders all 5 tabs including Cartons and navigates to Cartons view', (tester) async {
      final mockCards = [
        const CardEntry(
          rank: 1,
          playerId: 'p2',
          name: 'Karim Benali',
          nickname: 'Kaka',
          matchesPlayed: 8,
          yellowCards: 2,
          redCards: 1,
          totalCards: 3,
        ),
        const CardEntry(
          rank: 2,
          playerId: 'p1',
          name: 'Lucas',
          nickname: 'Lulu',
          matchesPlayed: 14,
          yellowCards: 1,
          redCards: 0,
          totalCards: 1,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            topCardsProvider.overrideWith((ref) => Future.value(mockCards)),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const StandingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check all 5 tabs exist
      expect(find.text('Points'), findsOneWidget);
      expect(find.text('Pts / Match'), findsOneWidget);
      expect(find.text('Buteurs'), findsOneWidget);
      expect(find.text('Passeurs'), findsOneWidget);
      expect(find.text('Cartons'), findsOneWidget);

      // Tap on Cartons tab
      await tester.tap(find.text('Cartons'));
      await tester.pumpAndSettle();

      // Check Cartons view elements
      expect(find.text('Tous'), findsOneWidget);
      expect(find.text('Cartons jaunes'), findsOneWidget);
      expect(find.text('Cartons rouges'), findsOneWidget);
      expect(find.text('Karim Benali'), findsOneWidget);
      expect(find.text('« Kaka »'), findsOneWidget);
      expect(find.text('Lucas'), findsOneWidget);
    });
  });
}
