import 'package:flutter_test/flutter_test.dart';
import 'package:statoo/features/ranking/domain/mvp_calculator.dart';
import 'package:statoo/features/ranking/domain/mvp_weights.dart';

void main() {
  group('MvpWeights', () {
    test('defaults match the historical scale', () {
      const w = MvpWeights.defaults;
      expect(
        [w.win, w.draw, w.loss, w.goal, w.assist, w.yellowCard, w.redCard],
        [10, 3, 0, 2, 1, 0.5, 1],
      );
      expect(w.isDefault, isTrue);
    });

    test('encode/decode round-trips', () {
      const custom = MvpWeights(win: 8, draw: 2.5, goal: 3, yellowCard: 1);
      expect(MvpWeights.decode(custom.encode()), custom);
      expect(custom.isDefault, isFalse);
    });

    test('missing or corrupted values fall back to defaults', () {
      expect(MvpWeights.decode(null), MvpWeights.defaults);
      expect(MvpWeights.decode(''), MvpWeights.defaults);
      expect(MvpWeights.decode('not json'), MvpWeights.defaults);
      expect(MvpWeights.decode('[1,2]'), MvpWeights.defaults);
      expect(
        MvpWeights.decode('{"win": "x", "goal": 5}'),
        const MvpWeights(goal: 5),
      );
    });
  });

  group('MvpCalculator with custom weights', () {
    test('applies custom weights to every component', () {
      const w = MvpWeights(win: 5, draw: 2, loss: 1, goal: 3, assist: 2, yellowCard: 1, redCard: 4);
      // Win 5 + 2 goals (6) + 1 assist (2) - 1 yellow (1) - 1 red (4) = 8
      expect(
        MvpCalculator.calculateMatchScore(
          isWin: true,
          isDraw: false,
          goals: 2,
          assists: 1,
          yellowCards: 1,
          redCards: 1,
          weights: w,
        ),
        8.0,
      );
      // Loss weight applies when neither win nor draw.
      expect(
        MvpCalculator.calculateMatchScore(
          isWin: false,
          isDraw: false,
          goals: 0,
          assists: 0,
          yellowCards: 0,
          redCards: 0,
          weights: w,
        ),
        1.0,
      );
    });

    test('default weights keep the previous behaviour', () {
      expect(
        MvpCalculator.calculateMatchScore(
          isWin: true,
          isDraw: false,
          goals: 2,
          assists: 1,
          yellowCards: 0,
          redCards: 0,
        ),
        15.0,
      );
    });
  });
}
