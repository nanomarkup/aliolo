import 'dart:math';
import 'package:aliolo/data/models/card_model.dart';
import 'package:aliolo/data/models/subject_model.dart';

class MathService {
  static final MathService _instance = MathService._internal();
  factory MathService() => _instance;
  MathService._internal();

  ({String question, String answer, List<String> options}) generateProblem(
    SubjectModel subject,
  ) {
    final random = Random();
    int a = 0;
    int b = 0;
    String op = '+';
    int ans = 0;

    final maxVal = subject.maxOperand;

    if (subject.isAddition) {
      a = random.nextInt(maxVal + 1);
      b = random.nextInt(maxVal + 1);
      ans = a + b;
      op = '+';
    } else if (subject.isSubtraction) {
      a = random.nextInt(maxVal) + 1;
      b = random.nextInt(a + 1);
      ans = a - b;
      op = '-';
    } else if (subject.isMultiplication) {
      a = random.nextInt(maxVal + 1);
      b = random.nextInt(11); // standard 0-10
      ans = a * b;
      op = '×';
    } else if (subject.isDivision) {
      b = random.nextInt(maxVal) + 1;
      ans = random.nextInt(11);
      a = ans * b;
      op = '÷';
    } else {
      // Fallback
      return (question: '0 + 0', answer: '0', options: ['0', '1', '2', '3']);
    }

    final question = '$a $op $b';
    final answer = ans.toString();
    final options = generateDistractors(ans, 6);

    return (question: question, answer: answer, options: options);
  }

  CardModel createVirtualCard(
    ({String question, String answer, List<String> options}) problem,
    int level,
  ) {
    final now = DateTime.now();
    // Unique ID to avoid issues
    final card = CardModel(
      id: 'math_${now.microsecondsSinceEpoch}_${Random().nextInt(1000)}',
      subjectId: 'Math',
      level: level,
      renderer: 'generic',
      ownerId: 'system',
      isPublic: true,
      createdAt: now,
      updatedAt: now,
      answer: problem.answer,
      prompt: '',
      displayText: problem.question,
    );
    card.mathOptions = problem.options;
    return card;
  }

  List<String> generateDistractors(int correct, int count) {
    final List<int> distractors = [];
    final random = Random();
    
    int attempts = 0;
    while (distractors.length < count - 1 && attempts < 100) {
      attempts++;
      int range = correct < 10 ? 5 : (correct < 50 ? 10 : 20);
      int offset = random.nextInt(range * 2) - range; 
      int val = correct + offset;
      
      if (val >= 0 && val != correct && !distractors.contains(val)) {
        distractors.add(val);
      }
    }
    
    int fallback = 0;
    while (distractors.length < count - 1) {
      if (fallback != correct && !distractors.contains(fallback)) {
        distractors.add(fallback);
      }
      fallback++;
    }

    distractors.add(correct);
    distractors.shuffle();
    return distractors.map((e) => e.toString()).toList();
  }
}
