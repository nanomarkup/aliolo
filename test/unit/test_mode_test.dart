import 'dart:math';

import 'package:aliolo/features/testing/domain/test_mode.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedRandom implements Random {
  final bool value;

  _FixedRandom(this.value);

  @override
  bool nextBool() => value;

  @override
  double nextDouble() => value ? 1.0 : 0.0;

  @override
  int nextInt(int max) => value ? max - 1 : 0;
}

void main() {
  group('TestModeChoice', () {
    test('questionToAnswer resolves to forward direction', () {
      expect(
        TestModeChoice.questionToAnswer.resolve(_FixedRandom(false)),
        TestDirection.questionToAnswer,
      );
    });

    test('answerToQuestion resolves to reverse direction', () {
      expect(
        TestModeChoice.answerToQuestion.resolve(_FixedRandom(false)),
        TestDirection.answerToQuestion,
      );
    });

    test('random resolves using the provided random source', () {
      expect(
        TestModeChoice.random.resolve(_FixedRandom(false)),
        TestDirection.questionToAnswer,
      );
      expect(
        TestModeChoice.random.resolve(_FixedRandom(true)),
        TestDirection.answerToQuestion,
      );
    });
  });
}
