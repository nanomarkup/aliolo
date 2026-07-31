import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  group('public landing page', () {
    late String html;

    setUpAll(() {
      html = File('web/index.html').readAsStringSync();
    });

    test('keeps conversion, product proof, and accessibility essentials', () {
      expect(html, contains('<a class="skip-link" href="#main-content">'));
      expect(html, contains('id="main-content"'));
      expect(html, contains('Learn visually. Remember longer.'));
      expect(html, contains('src="/landing-product-preview.jpg"'));
      expect(
        html,
        contains(
          'href="/login" class="btn btn-primary">Create free account</a>',
        ),
      );
      expect(
        html,
        contains('href="/?login=1" class="btn btn-secondary">Log in</a>'),
      );
      expect(html, contains('aria-label="View monthly plan details"'));
      expect(html, contains(':focus-visible'));
      expect(html, contains('prefers-reduced-motion'));
      expect(html, isNot(contains('payment partners')));
      expect(html, isNot(contains('Paddle review')));
      expect(html, isNot(contains('crawlable learning content')));
    });

    test('uses a correctly sized social sharing image', () {
      expect(
        html,
        contains(
          '<meta property="og:image" content="https://aliolo.com/aliolo-social-preview.png">',
        ),
      );

      final bytes = File('web/aliolo-social-preview.png').readAsBytesSync();
      final preview = image.decodePng(bytes);
      expect(preview, isNotNull);
      expect(preview!.width, 1200);
      expect(preview.height, 630);
    });
  });
}
