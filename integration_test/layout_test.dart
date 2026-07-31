import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:aliolo/main.dart';

void main() {
  PatrolBinding.ensureInitialized(PlatformAutomator());

  patrolTest(
    'Layout responsiveness and key elements',
    ($) async {
      await $.pumpWidgetAndSettle(const AlioloApp());

      // Let's assume we land on either a Login screen or the main Dashboard.
      // If we see a Login screen, the layout is correct for an unauthenticated user.
      final isLoginPage = $(TextField).exists;
      
      if (isLoginPage) {
        expect($(TextField).first, findsOneWidget); // Email field
        expect($(TextField).last, findsOneWidget); // Password field
        expect($('Login'), findsWidgets);
      } else {
        // Assume authenticated Dashboard / Subjects page
        // Wait for the app bar or bottom navigation
        expect($(AppBar), findsWidgets);
        
        // We should see a list or grid of subjects
        expect($(ListView), findsWidgets);
      }
    },
  );
}
