import 'package:aliolo/core/theme/aliolo_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds a shared control theme with filled surfaces and rounded cards', () {
    final theme = AlioloTheme.build(
      seedColor: Colors.blue,
      brightness: Brightness.light,
    );

    expect(theme.useMaterial3, isTrue);
    expect(theme.inputDecorationTheme.filled, isTrue);
    expect(theme.inputDecorationTheme.fillColor, theme.colorScheme.surfaceContainerHighest);
    expect(theme.cardTheme.color, theme.colorScheme.surfaceContainerHighest);

    final shape = theme.cardTheme.shape;
    expect(shape, isA<RoundedRectangleBorder>());
    final rounded = shape as RoundedRectangleBorder;
    expect(rounded.borderRadius, BorderRadius.circular(16));
  });
}

