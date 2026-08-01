import 'package:aliolo/core/utils/io_utils.dart'
    if (dart.library.html) 'package:aliolo/core/utils/file_stub.dart'
    as io;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aliolo/core/utils/logger.dart';
import 'package:nanomarkup/nanomarkup.dart' as nano;

/// Runtime UI translation service.
///
/// This resolves chrome / app-label strings using local .nano files bundled
/// with the application.
///
/// Card and subject content localization is handled separately through the
/// localized fields on those models.
class TranslationService extends ChangeNotifier {
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();

  Locale _currentLocale = const Locale('en');
  Locale get currentLocale => _currentLocale;

  Map<String, String> _translations = {};
  Map<String, String> _englishFallbacks = {};

  static const List<String> supportedUILanguages = [
    'en',
    'id',
    'bg',
    'cs',
    'da',
    'de',
    'et',
    'es',
    'fr',
    'ga',
    'hr',
    'it',
    'lv',
    'lt',
    'hu',
    'mt',
    'nl',
    'pl',
    'pt',
    'ro',
    'sk',
    'sl',
    'fi',
    'sv',
    'tl',
    'vi',
    'tr',
    'el',
    'uk',
    'ar',
    'hi',
    'zh',
    'ja',
    'ko',
  ];

  static const Map<String, String> _languageNames = {
    'en': 'English',
    'id': 'Indonesian',
    'bg': 'Bulgarian',
    'cs': 'Czech',
    'da': 'Danish',
    'de': 'German',
    'et': 'Estonian',
    'es': 'Spanish',
    'fr': 'French',
    'ga': 'Irish',
    'hr': 'Croatian',
    'it': 'Italian',
    'lv': 'Latvian',
    'lt': 'Lithuanian',
    'hu': 'Hungarian',
    'mt': 'Maltese',
    'nl': 'Dutch',
    'pl': 'Polish',
    'pt': 'Portuguese',
    'ro': 'Romanian',
    'sk': 'Slovak',
    'sl': 'Slovenian',
    'fi': 'Finnish',
    'sv': 'Swedish',
    'tl': 'Tagalog',
    'vi': 'Vietnamese',
    'tr': 'Turkish',
    'el': 'Greek',
    'uk': 'Ukrainian',
    'ar': 'Arabic',
    'hi': 'Hindi',
    'zh': 'Chinese',
    'ja': 'Japanese',
    'ko': 'Korean',
  };

  List<String> get availableUILanguages => supportedUILanguages;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedLocale = prefs.getString('ui_locale');

    await _loadLocalEnglishFallback();

    String langCode = 'en';
    if (savedLocale != null && supportedUILanguages.contains(savedLocale)) {
      langCode = savedLocale;
      _currentLocale = Locale(langCode);
    } else {
      try {
        if (!kIsWeb) {
          final String systemLocale =
              io.Platform.localeName.split('_')[0].toLowerCase();
          if (supportedUILanguages.contains(systemLocale)) {
            langCode = systemLocale;
            _currentLocale = Locale(langCode);
            await prefs.setString('ui_locale', langCode);
          }
        }
      } catch (_) {}
    }

    await loadTranslations(langCode);
  }

  Future<void> _loadLocalEnglishFallback() async {
    try {
      final localNano = await rootBundle.loadString(
        'assets/translations/en.nano',
      );
      final decoded = nano.decode(localNano);
      if (decoded is Map) {
        _englishFallbacks = decoded.map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        );
        if (_translations.isEmpty) {
          _translations = Map<String, String>.from(_englishFallbacks);
        }
      }
    } catch (e) {
      AppLogger.log('Translation: Failed to load local en.nano fallback: $e');
    }
  }

  Future<void> loadTranslations(String langCode) async {
    final lc = langCode.toLowerCase();

    // Start with English fallbacks
    _translations = Map<String, String>.from(_englishFallbacks);

    if (!supportedUILanguages.contains(lc)) return;
    if (lc == 'en') return;

    // Try to load local bundled asset translations
    try {
      final localNano = await rootBundle.loadString(
        'assets/translations/$lc.nano',
      );
      final decoded = nano.decode(localNano);
      if (decoded is Map) {
        decoded.forEach((k, v) {
          _translations[k.toString()] = v.toString();
        });
        AppLogger.log('Translation: Loaded local asset translations for $lc');
      }
    } catch (e) {
      AppLogger.log('Translation: Local asset not found or failed for $lc: $e');
    }
  }

  void setLocale(Locale locale, {bool persistGlobal = true}) async {
    if (_currentLocale == locale) return;

    final langCode =
        supportedUILanguages.contains(locale.languageCode)
            ? locale.languageCode
            : 'en';

    _currentLocale = Locale(langCode);
    await loadTranslations(langCode);
    notifyListeners();

    if (persistGlobal) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ui_locale', langCode);
    }
  }

  String translate(String key, {Map<String, String>? args}) {
    String? value = _translations[key];
    if (value == null || value.trim().isEmpty) value = _englishFallbacks[key];
    if (value == null || value.trim().isEmpty) value = key;

    if (args != null) {
      args.forEach((k, v) => value = value!.replaceAll('{$k}', v));
    }
    return value!;
  }

  String getLanguageName(String code) {
    final lc = code.toLowerCase();
    if (_languageNames.containsKey(lc)) return _languageNames[lc]!;
    return code.toUpperCase();
  }
}

extension TranslationExtension on BuildContext {
  String t(String key, {Map<String, String>? args}) {
    try {
      return TranslationService().translate(key, args: args);
    } catch (_) {
      return key;
    }
  }

  String plural(String baseKey, int count) {
    final key = count == 1 ? '${baseKey}_label' : '${baseKey}_plural';
    return t(key);
  }
}
