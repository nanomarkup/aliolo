import 'package:aliolo/data/models/card_model.dart';

int compareCardsByLevelThenAnswer(
  CardModel a,
  CardModel b,
  String languageCode,
) {
  final levelCompare = a.level.compareTo(b.level);
  if (levelCompare != 0) return levelCompare;

  final aAnswer = a.getAnswer(languageCode).toLowerCase();
  final bAnswer = b.getAnswer(languageCode).toLowerCase();
  final answerCompare = aAnswer.compareTo(bAnswer);
  if (answerCompare != 0) return answerCompare;

  return a.id.compareTo(b.id);
}

void sortCardsByLevelThenAnswer(
  List<CardModel> cards,
  String languageCode,
) {
  cards.sort((a, b) => compareCardsByLevelThenAnswer(a, b, languageCode));
}
