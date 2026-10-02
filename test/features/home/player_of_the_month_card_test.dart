import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/home/presentation/home_screen.dart';
import 'package:statoo/features/ranking/application/ranking_providers.dart';
import 'package:statoo/features/ranking/domain/mvp_entry.dart';

void main() {
  group('HomeScreen Player of the Month card', () {
    testWidgets('displays Joueur du mois card with month label when MVP exists', (tester) async {
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
        assists: 1,
        yellowCards: 0,
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
