import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/sessions/domain/session.dart';
import 'package:statoo/features/sessions/domain/participation.dart';
import 'package:statoo/features/sessions/domain/session_summary.dart';
import 'package:statoo/features/sessions/presentation/session_header.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets('INT-13 no empty labels, no heading, ball xN', (tester) async {
    Future<void> pump(int goals) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: SessionHeader(
            session: Session(
              id: 's',
              playedAt: DateTime(2026),
              scoreA: goals,
              scoreB: 0,
            ),
            participants: [
              SessionParticipantDetail(
                participation: Participation(
                  id: 'p',
                  sessionId: 's',
                  playerId: 'p',
                  team: Team.a,
                  goals: goals,
                ),
                playerName: 'Karim',
              ),
            ],
            formattedDate: '17 octobre',
            formatLabel: '5v5',
            isCurrentActive: true,
            canEdit: false,
            onScoreIncrement: (_, __) {},
          ),
        ),
      ),
    );
    await pump(0);
    expect(find.byKey(const ValueKey('session-scorers')), findsNothing);
    await pump(2);
    expect(find.text('x2'), findsOneWidget);
    expect(find.text('Buteurs de la séance'), findsNothing);
    expect(find.text('Aucun buteur'), findsNothing);
    await pump(1);
    expect(find.text('x1'), findsNothing);
    expect(find.text('Karim'), findsOneWidget);
  });
}
