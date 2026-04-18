import 'package:flutter_test/flutter_test.dart';
import 'package:aliolo/core/utils/card_sorting.dart';
import 'package:aliolo/data/models/card_model.dart';

CardModel _card({
  required String id,
  required int level,
  required String answer,
}) {
  return CardModel(
    id: id,
    subjectId: 'subject',
    level: level,
    renderer: 'generic',
    ownerId: 'owner',
    isPublic: true,
    createdAt: DateTime(2026, 4, 13),
    updatedAt: DateTime(2026, 4, 13),
    answer: answer,
    prompt: '',
  );
}

void main() {
  test('sortCardsByLevelThenAnswer sorts by level then answer', () {
    final cards = [
      _card(id: 'c', level: 2, answer: 'Banana'),
      _card(id: 'a', level: 1, answer: 'Zebra'),
      _card(id: 'b', level: 1, answer: 'Apple'),
      _card(id: 'd', level: 2, answer: 'Apple'),
    ];

    sortCardsByLevelThenAnswer(cards, 'en');

    expect(cards.map((c) => c.id).toList(), ['b', 'a', 'd', 'c']);
  });
}
