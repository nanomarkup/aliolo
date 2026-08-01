import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aliolo/data/services/translation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TranslationService', () {
    test(
      'init loads local fallback and initializes with default locale',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler('flutter/assets', (message) async {
              final Uint8List encoded = Uint8List.fromList(
                '..\n    about About\n    cancel Cancel\n'.codeUnits,
              );
              return ByteData.sublistView(encoded);
            });

        final translationService = TranslationService();
        await translationService.init();

        expect(translationService.currentLocale.languageCode, equals('en'));
        expect(translationService.translate('about'), equals('About'));
        expect(translationService.translate('cancel'), equals('Cancel'));
        expect(
          translationService.translate('non_existent'),
          equals('non_existent'),
        );
      },
    );

    test('translate uses local language assets when available', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (message) async {
            final Uint8List encoded = Uint8List.fromList(
              '..\n    about Acerca de\n'.codeUnits,
            );
            return ByteData.sublistView(encoded);
          });

      final translationService = TranslationService();
      await translationService.loadTranslations('es');

      expect(translationService.translate('about'), equals('Acerca de'));
    });

    test('detects startup language from localized URL prefix', () {
      expect(
        TranslationService.languageFromInitialUrl(
          'https://aliolo.com/tr/login',
        ),
        equals('tr'),
      );
      expect(
        TranslationService.languageFromInitialUrl(
          'https://aliolo.com/sk/login?login=1',
        ),
        equals('sk'),
      );
      expect(
        TranslationService.languageFromInitialUrl(
          'https://aliolo.com/login?lang=es',
        ),
        equals('es'),
      );
      expect(
        TranslationService.languageFromInitialUrl(
          'https://aliolo.com/ru/login',
        ),
        isNull,
      );
    });
  });
}
