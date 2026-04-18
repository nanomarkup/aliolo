import 'dart:math';

import 'package:flutter/material.dart';

enum TestModeChoice { questionToAnswer, answerToQuestion, random }

enum TestDirection { questionToAnswer, answerToQuestion }

extension TestModeChoiceX on TestModeChoice {
  String get storageValue => switch (this) {
    TestModeChoice.questionToAnswer => 'question_to_answer',
    TestModeChoice.answerToQuestion => 'answer_to_question',
    TestModeChoice.random => 'random',
  };

  String get label => switch (this) {
    TestModeChoice.questionToAnswer => 'Q → A',
    TestModeChoice.answerToQuestion => 'A → Q',
    TestModeChoice.random => 'Random',
  };

  IconData get icon => switch (this) {
    TestModeChoice.questionToAnswer => Icons.school,
    TestModeChoice.answerToQuestion => Icons.swap_horiz,
    TestModeChoice.random => Icons.shuffle,
  };

  TestDirection resolve(Random random) {
    switch (this) {
      case TestModeChoice.questionToAnswer:
        return TestDirection.questionToAnswer;
      case TestModeChoice.answerToQuestion:
        return TestDirection.answerToQuestion;
      case TestModeChoice.random:
        return random.nextBool()
            ? TestDirection.answerToQuestion
            : TestDirection.questionToAnswer;
    }
  }
}

TestModeChoice parseTestModeChoice(String? value) {
  switch (value?.trim().toLowerCase()) {
    case 'answer_to_question':
      return TestModeChoice.answerToQuestion;
    case 'random':
      return TestModeChoice.random;
    case 'question_to_answer':
    default:
      return TestModeChoice.questionToAnswer;
  }
}
