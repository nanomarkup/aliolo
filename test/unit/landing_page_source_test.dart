import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  group('web application assets', () {
    late String html;
    late String wranglerConfig;

    setUpAll(() {
      html = File('web/index.html').readAsStringSync();
      wranglerConfig = File('api/wrangler.jsonc').readAsStringSync();
    });

    test('uses one minimal, non-indexable Flutter application shell', () {
      expect(html, contains('<html lang="en">'));
      expect(html, contains('<meta name="robots" content="noindex,nofollow">'));
      expect(
        html,
        contains('<link rel="canonical" href="https://aliolo.com/login">'),
      );
      expect(
        html,
        contains('<link rel="icon" type="image/webp" href="app_icon.webp">'),
      );
      expect(html, contains('<link rel="manifest" href="manifest.json">'));
      expect(
        html,
        contains('<script src="flutter_bootstrap.js" async></script>'),
      );
      expect(
        html,
        contains("window.postMessage('flutter-app-update-available'"),
      );
      expect(html, isNot(contains('Learn visually. Remember longer.')));
    });

    test('runs the Worker before static assets on every environment', () {
      expect(
        RegExp('"run_worker_first": true').allMatches(wranglerConfig).length,
        2,
      );
    });

    test('provides a correctly sized social sharing image asset', () {
      final bytes = File('web/aliolo-social-preview.png').readAsBytesSync();
      final preview = image.decodePng(bytes);
      expect(preview, isNotNull);
      expect(preview!.width, 1200);
      expect(preview.height, 630);
    });
  });
}
