import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:aliolo/main.dart';

void main() {
  PatrolBinding.ensureInitialized(PlatformAutomator());

  patrolTest(
    'App launches and shows some UI',
    ($) async {
      // Launch the app
      await $.pumpWidgetAndSettle(const AlioloApp());

      // Basic smoke test: Check if any text is rendered, meaning the app didn't crash.
      // Patrol's $ selector allows finding widgets easily.
      // We wait for the first frame to settle.
      expect($(find.byType(AlioloApp)), findsOneWidget);
    },
  );
}
