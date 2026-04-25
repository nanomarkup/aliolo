import 'package:aliolo/core/widgets/aliolo_compact_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('filled compact dropdown uses card-like surface', (tester) async {
    const surfaceKey = Key('dropdown-surface');

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(cardColor: Colors.white),
        home: Scaffold(
          body: SizedBox(
            width: 220,
            child: AlioloCompactDropdown<String>(
              value: 'en',
              items: const {'en': 'English', 'es': 'Spanish'},
              selectedLabel: 'EN',
              useFilledSurfaceStyle: true,
              surfaceKey: surfaceKey,
            ),
          ),
        ),
      ),
    );

    final surfaceFinder = find.byKey(surfaceKey);
    expect(surfaceFinder, findsOneWidget);

    final surface = tester.widget<Container>(surfaceFinder);
    final decoration = surface.decoration as BoxDecoration;
    expect(decoration.color, const Color.fromRGBO(255, 255, 255, 0.5));
    expect(decoration.border, isA<Border>());
  });
}
