import 'package:aliolo/data/models/card_model.dart';

class MathService {
  static final MathService _instance = MathService._internal();
  factory MathService() => _instance;
  MathService._internal();

  ({String question, String answer, List<String> options}) generateProblem(int level) {
    // Logic for generating math problems...
    return (question: '2 + 2', answer: '4', options: ['3', '4', '5', '6']);
  }

  CardModel createVirtualCard(({String question, String answer, List<String> options}) problem, int level) {
    final now = DateTime.now();
    final card = CardModel(
      id: 'math_${now.millisecondsSinceEpoch}',
      subjectId: 'math',
      level: level,
      prompts: {'en': problem.question},
      answers: {'en': problem.answer},
      ownerId: 'system',
      isPublic: true,
      createdAt: now,
      updatedAt: now,
    );
    card.mathQuestion = problem.question;
    card.mathOptions = problem.options;
    return card;
  }
}
