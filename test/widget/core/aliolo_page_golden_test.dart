import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:aliolo/core/widgets/aliolo_page.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
  });

  group('AlioloPage Golden Tests', () {
    testGoldens('AlioloPage should look correct with basic content', (tester) async {
      final builder = DeviceBuilder()
        ..overrideDevicesForAllScenarios(devices: [
          Device.phone,
          Device.iphone11,
          Device.tabletPortrait,
        ])
        ..addScenario(
          widget: const AlioloPage(
            title: Text('Golden Title'),
            body: Center(
              child: Text(
                'Golden Body Content',
                style: TextStyle(fontSize: 24),
              ),
            ),
          ),
          name: 'basic_layout',
        );

      await tester.pumpDeviceBuilder(builder);

      // Verify the visual appearance matches the golden snapshot
      await screenMatchesGolden(tester, 'aliolo_page_basic');
    });
  });
}
