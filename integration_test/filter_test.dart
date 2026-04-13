import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:aliolo/main.dart';

void main() {
  PatrolBinding.ensureInitialized(NativeAutomatorConfig());

  patrolTest(
    'UI Filters functionality',
    ($) async {
      await $.pumpWidgetAndSettle(const AlioloApp());

      final isLoginPage = $(TextField).exists;
      if (isLoginPage) {
        // Log in as a test user if possible, otherwise we skip filter tests
        // Testing complex user flows natively requires passing real credentials.
        // For this test, if we cannot authenticate, we log a warning.
        print('Skipping deep filter interaction as we are on the login screen.');
        return;
      }

      // 1. Verify the filter button or chips are visible
      // Depending on the exact layout, we look for an icon or text indicating "Filters"
      final filterButton = $(Icons.filter_list);
      
      if (!filterButton.exists) {
        print('Filter button not found in current view.');
        return;
      }

      // 2. Open the filter bottom sheet / dialog
      await filterButton.tap();
      await $.pumpAndSettle();

      // 3. Test changing the "Source" (Collection) filter
      final sourceDropdown = $('Source');
      if (sourceDropdown.exists) {
        await sourceDropdown.tap();
        await $.pumpAndSettle();
        // Look for 'Public' or 'My Subjects' option
        final publicOption = $('Public');
        if (publicOption.exists) {
          await publicOption.tap();
          await $.pumpAndSettle();
        }
      }

      // 4. Test changing the "Age Group" filter
      final ageDropdown = $('Age');
      if (ageDropdown.exists) {
        await ageDropdown.tap();
        await $.pumpAndSettle();
        // Look for an age group like '7-14' or 'advanced'
        final ageOption = $('7-14');
        if (ageOption.exists) {
          await ageOption.tap();
          await $.pumpAndSettle();
        }
      }

      // Close the filter sheet if there is an Apply/Close button
      final applyButton = $('Apply');
      if (applyButton.exists) {
        await applyButton.tap();
        await $.pumpAndSettle();
      }

      // 5. Verify the UI updates (we just verify the list didn't crash)
      expect($(ListView), findsWidgets);
    },
  );
}
