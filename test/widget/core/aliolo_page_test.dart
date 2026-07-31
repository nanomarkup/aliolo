import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aliolo/core/widgets/aliolo_page.dart';

void main() {
  group('AlioloPage', () {
    testWidgets('should display title and body', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await tester.pumpWidget(
          const MaterialApp(
            home: AlioloPage(
              title: Text('Test Title'),
              body: Text('Test Body'),
            ),
          ),
        );

        expect(find.text('Test Title'), findsOneWidget);
        expect(find.text('Test Body'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('should show actions when provided', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await tester.pumpWidget(
          const MaterialApp(
            home: AlioloPage(
              title: Text('Title'),
              actions: [
                Icon(Icons.add, key: Key('action-icon')),
              ],
              body: SizedBox(),
            ),
          ),
        );

        expect(find.byKey(const Key('action-icon')), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
