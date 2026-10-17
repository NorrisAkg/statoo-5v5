import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statoo/features/sessions/domain/session.dart';
import 'package:statoo/features/sessions/presentation/session_celebration.dart';

void main() {
  final s = Session(
    id: 's',
    playedAt: DateTime(2026),
    scoreA: 2,
    scoreB: 0,
    teamNames: const {'A': 'Atlas', 'B': 'Union', 'C': 'Sporting'},
  );
  test('REF-07 correct winner and all tie variants', () {
    expect(sessionCelebrationMessage(s), contains('Atlas'));
    expect(sessionCelebrationMessage(s.copyWith(scoreB: 3)), contains('Union'));
    expect(
      sessionCelebrationMessage(s.copyWith(scoreB: 2)),
      contains('Bravo à tous'),
    );
    final t = s.copyWith(
      sessionType: SessionType.tournament3,
      winsA: 1,
      winsB: 2,
      winsC: 3,
    );
    expect(sessionCelebrationMessage(t), contains('Sporting'));
    expect(
      sessionCelebrationMessage(t.copyWith(winsA: 3)),
      allOf(contains('Atlas'), contains('Sporting')),
    );
    expect(
      sessionCelebrationMessage(t.copyWith(winsA: 3, winsB: 3)),
      contains('Bravo à tous'),
    );
  });
  for (final reduced in [false, true])
    testWidgets('REF-09 animation reduced=$reduced', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: SessionCelebration(session: s),
          ),
        ),
      );
      expect(find.textContaining('Atlas'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('celebration-confetti')),
        reduced ? findsNothing : findsOneWidget,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  for (final width in [320.0, 393.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets('REF-10 celebration $width $scale dark=$dark', (tester) async {
          tester.view.physicalSize = Size(width, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(MaterialApp(
            theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
            home: MediaQuery(data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: SessionCelebration(session: s.copyWith(teamNames: const {'A': 'Association sportive au nom particulièrement long'}))),
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Continuer'), findsOneWidget);
        });
      }
    }
  }
}
