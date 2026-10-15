import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:statoo/features/sessions/domain/session.dart';
import 'package:statoo/features/sessions/domain/session_team_names.dart';

void main() {
  test('classic sessions draw two distinct club names from the catalogue', () {
    final names = drawSessionTeamNames(SessionType.classic2, random: Random(1));
    expect(names.keys, ['A', 'B']);
    expect(names.values.toSet(), hasLength(2));
    expect(names.values.every(sessionTeamNames.contains), isTrue);
  });

  test('tournaments draw three distinct club names', () {
    final names = drawSessionTeamNames(
      SessionType.tournament3,
      random: Random(2),
    );
    expect(names.keys, ['A', 'B', 'C']);
    expect(names.values.toSet(), hasLength(3));
  });

  test(
    'catalogue offers at least 100 unique names compatible with storage',
    () {
      expect(sessionTeamNames.length, greaterThanOrEqualTo(100));
      expect(sessionTeamNames.toSet().length, sessionTeamNames.length);
      expect(sessionTeamNames.every((name) => name.length <= 30), isTrue);
    },
  );
}
