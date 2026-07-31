import 'package:aliolo/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('landing page navigation', () {
    test('login links bypass first-visit onboarding', () {
      expect(
        shouldSkipOnboardingForInitialUrl('https://aliolo.com/login?login=1'),
        isTrue,
      );
    });

    test('account creation links retain first-visit onboarding', () {
      expect(
        shouldSkipOnboardingForInitialUrl('https://aliolo.com/login'),
        isFalse,
      );
      expect(shouldSkipOnboardingForInitialUrl(null), isFalse);
    });
  });
}
