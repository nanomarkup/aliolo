import 'package:aliolo/core/widgets/card_media_content.dart';
import 'package:aliolo/data/models/card_model.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CardModel buildColorCard() {
    return CardModel(
      id: 'card_1',
      subjectId: 'subject_1',
      ownerId: 'owner_1',
      isPublic: true,
      createdAt: DateTime(2026, 4, 30),
      updatedAt: DateTime(2026, 4, 30),
      renderer: 'colors',
      answer: 'Blue',
      prompt: 'Pick the color',
      displayText: '#0000ff',
    );
  }

  SubjectModel buildSubject() {
    return SubjectModel(
      id: 'subject_1',
      pillarId: 1,
      ownerId: 'owner_1',
      isPublic: true,
      createdAt: DateTime(2026, 4, 30),
      updatedAt: DateTime(2026, 4, 30),
      name: 'Colors',
      description: 'Colors subject',
    );
  }

  testWidgets('renders colors card with visible surface on mobile width', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: CardMediaContent(
                card: buildColorCard(),
                subject: buildSubject(),
                languageCode: 'en',
                headerColor: Colors.blue,
                isMobile: true,
                headerText: 'Pick the color',
              ),
            ),
          ),
        ),
      ),
    );

    final surface = find.byKey(const Key('color-card-surface'));
    expect(surface, findsOneWidget);

    final surfaceSize = tester.getSize(surface);
    expect(surfaceSize.width, greaterThan(200));
    expect(surfaceSize.height, greaterThan(200));

    final cardFinder = find.byType(Card);
    expect(cardFinder, findsOneWidget);
    expect(tester.getSize(cardFinder).height, greaterThanOrEqualTo(300));

    expect(find.byKey(const Key('color-hex-label')), findsOneWidget);
  });

  testWidgets('renders colors card with visible surface on narrow web layout', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 420,
              height: 420,
              child: CardMediaContent(
                card: buildColorCard(),
                subject: buildSubject(),
                languageCode: 'en',
                headerColor: Colors.blue,
                isMobile: false,
                headerText: 'Pick the color',
              ),
            ),
          ),
        ),
      ),
    );

    final surface = find.byKey(const Key('color-card-surface'));
    expect(surface, findsOneWidget);

    final surfaceSize = tester.getSize(surface);
    expect(surfaceSize.width, greaterThan(200));
    expect(surfaceSize.height, greaterThan(200));

    expect(find.byKey(const Key('color-hex-label')), findsOneWidget);
  });

  testWidgets(
    'renders colors card with visible surface inside stacked scroll layout',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    width: 900,
                    child: CardMediaContent(
                      card: buildColorCard(),
                      subject: buildSubject(),
                      languageCode: 'en',
                      headerColor: Colors.blue,
                      isMobile: false,
                      headerText: 'Pick the color',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final surface = find.byKey(const Key('color-card-surface'));
      expect(surface, findsOneWidget);

      final surfaceSize = tester.getSize(surface);
      expect(surfaceSize.width, greaterThan(200));
      expect(surfaceSize.height, greaterThan(200));

      expect(find.byKey(const Key('color-hex-label')), findsOneWidget);
    },
  );
}
