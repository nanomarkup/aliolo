import 'package:aliolo/features/testing/presentation/widgets/session_completion_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows shared completion shell and action', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: SessionCompletionWindow(
          subjectTitle: 'Colors',
          headerColor: Colors.blue,
          onBackPressed: () {
            tapped = true;
          },
          body: const Text('Shared body'),
          actionLabel: 'Back to Subjects',
        ),
      ),
    );

    expect(find.byType(SessionCompletionWindow), findsOneWidget);
    expect(find.text('Colors'), findsOneWidget);
    expect(find.text('Shared body'), findsOneWidget);
    expect(find.text('Back to Subjects'), findsOneWidget);

    await tester.tap(find.text('Back to Subjects'));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
