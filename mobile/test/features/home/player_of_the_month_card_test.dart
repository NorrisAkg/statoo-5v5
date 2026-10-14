import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/core/widgets/app_card.dart';
import 'package:statoo/core/widgets/soccer_shoe_icon.dart';
import 'package:statoo/features/home/presentation/home_screen.dart';
import 'package:statoo/features/ranking/application/ranking_providers.dart';
import 'package:statoo/features/ranking/domain/mvp_entry.dart';

void main() {
  group('HomeScreen Player of the Month card', () {
    testWidgets('displays Joueur du mois card with icon-based stats and card stats', (tester) async {
      const mockMvp = MvpEntry(
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
        assists: 2,
        yellowCards: 1,
        redCards: 0,
        score: 11.33,
        isEligible: true,
        missingMatches: 0,
        month: '2026-10',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playerOfTheMonthProvider.overrideWith((ref) => Future.value(mockMvp)),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Joueur du mois'), findsOneWidget);
      expect(find.textContaining('Octobre 2026'), findsOneWidget);
      expect(find.text('Karim'), findsOneWidget);
      expect(find.text('« Kaka »'), findsOneWidget);
      expect(find.textContaining('11.33'), findsOneWidget);

      final mvpCard = find.ancestor(
        of: find.textContaining('Joueur du mois'),
        matching: find.byType(AppCard),
      );

      // Icons must be used instead of text labels within the MVP card
      expect(find.descendant(of: mvpCard, matching: find.byIcon(Remix.football_line)), findsOneWidget);
      expect(find.descendant(of: mvpCard, matching: find.byType(SoccerShoeIcon)), findsOneWidget);
      expect(find.descendant(of: mvpCard, matching: find.byIcon(Remix.footprint_line)), findsNothing);
      expect(find.descendant(of: mvpCard, matching: find.byIcon(Remix.calendar_event_line)), findsOneWidget);
      expect(find.descendant(of: mvpCard, matching: find.text('5')), findsOneWidget); // goals
      expect(find.descendant(of: mvpCard, matching: find.text('2')), findsOneWidget); // assists
      expect(find.descendant(of: mvpCard, matching: find.text('3')), findsOneWidget); // matches played

      // No text labels 'buts', 'passes', 'MJ'
      expect(find.descendant(of: mvpCard, matching: find.textContaining('buts')), findsNothing);
      expect(find.descendant(of: mvpCard, matching: find.textContaining('passes')), findsNothing);
      expect(find.descendant(of: mvpCard, matching: find.textContaining('MJ')), findsNothing);

      // Card stats: yellow card (1) and red card (0)
      expect(find.descendant(of: mvpCard, matching: find.text('1')), findsOneWidget); // yellow card count
      expect(find.descendant(of: mvpCard, matching: find.text('0')), findsOneWidget); // red card count
    });

    testWidgets('displays pending state card when MVP is null', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playerOfTheMonthProvider.overrideWith((ref) => Future<MvpEntry?>.value()),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Joueur du mois'), findsOneWidget);
      expect(find.textContaining('En attente'), findsOneWidget);
    });
  });
}
