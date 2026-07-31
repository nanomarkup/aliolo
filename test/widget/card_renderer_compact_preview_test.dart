import 'package:aliolo/core/widgets/card_renderer.dart';
import 'package:aliolo/data/models/card_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CardModel buildColorCard() {
    return CardModel(
      id: 'card_1',
      subjectId: 'subject_1',
      ownerId: 'owner_1',
      isPublic: true,
      createdAt: DateTime(2026, 4, 25),
      updatedAt: DateTime(2026, 4, 25),
      renderer: 'colors',
      answer: 'Blue',
      prompt: '',
      displayText: '#0000ff',
    );
  }

  testWidgets('compact color preview fills the tile', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 160,
            child: CardRenderer(
              card: buildColorCard(),
              subject: null,
              languageCode: 'en',
              fallbackColor: Colors.blue,
              compactPreview: true,
            ),
          ),
        ),
      ),
    );

    final renderer = find.byType(CardRenderer);

    final coloredBoxFinder = find.descendant(
      of: renderer,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox &&
            widget.color == const Color(0xFF0000FF),
      ),
    );
    expect(coloredBoxFinder, findsOneWidget);
    expect(tester.getSize(coloredBoxFinder), const Size(200, 160));
    final coloredBox = tester.widget<ColoredBox>(coloredBoxFinder);
    expect(coloredBox.color, const Color(0xFF0000FF));

    final labelFinder = find.descendant(
      of: renderer,
      matching: find.byKey(const Key('color-hex-label')),
    );
    expect(labelFinder, findsOneWidget);
    expect(tester.getTopLeft(labelFinder).dy, lessThan(24));
    final label = tester.widget<DecoratedBox>(labelFinder);
    final decoration = label.decoration as BoxDecoration;
    expect(decoration.color, isNotNull);
  });

  testWidgets('default color preview also fills the tile', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 160,
            child: CardRenderer(
              card: buildColorCard(),
              subject: null,
              languageCode: 'en',
              fallbackColor: Colors.blue,
            ),
          ),
        ),
      ),
    );

    final renderer = find.byType(CardRenderer);
    final coloredBoxFinder = find.descendant(
      of: renderer,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox &&
            widget.color == const Color(0xFF0000FF),
      ),
    );
    expect(coloredBoxFinder, findsOneWidget);
    expect(tester.getSize(coloredBoxFinder), const Size(200, 160));

    final labelFinder = find.descendant(
      of: renderer,
      matching: find.byKey(const Key('color-hex-label')),
    );
    expect(labelFinder, findsOneWidget);
    expect(tester.getTopLeft(labelFinder).dy, lessThan(24));
  });
}
