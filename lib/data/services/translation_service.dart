import 'package:aliolo/core/utils/io_utils.dart' if (dart.library.html) 'package:aliolo/core/utils/file_stub.dart';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aliolo/core/network/cloudflare_client.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/core/utils/logger.dart';

/// Runtime UI translation service.
///
/// This only resolves chrome / app-label strings from the backend tables:
/// - `languages`
/// - `ui_translations`
///
/// Card and subject content localization is handled separately through the
/// localized fields on those models.
class TranslationService extends ChangeNotifier {
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();

  final _cfClient = getIt<CloudflareHttpClient>();

  Locale _currentLocale = const Locale('en');
  Locale get currentLocale => _currentLocale;

  Map<String, String> _translations = {};
  Map<String, String> _englishFallbacks = {};

  static const List<String> _fallbackUILanguages = [
    'en', 'id', 'bg', 'cs', 'da', 'de', 'et', 'es', 'fr', 'ga', 'hr', 'it', 'lv', 'lt', 'hu', 'mt', 'nl', 'pl', 'pt', 'ro', 'sk', 'sl', 'fi', 'sv', 'tl', 'vi', 'tr', 'el', 'uk', 'ar', 'hi', 'zh', 'ja', 'ko',
  ];

  List<String> _availableUILanguages = List.from(_fallbackUILanguages);
  List<String> get availableUILanguages => _availableUILanguages;

  final Map<String, String> _languageNames = {};

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedLocale = prefs.getString('ui_locale');

    await fetchAvailableLanguages();
    _englishFallbacks = await _fetchFromCloudflare('en');

    String langCode = 'en';
    if (savedLocale != null) {
      langCode = savedLocale;
      _currentLocale = Locale(langCode);
    } else {
      try {
        if (!kIsWeb) {
          final String systemLocale = Platform.localeName.split('_')[0].toLowerCase();
          if (_availableUILanguages.contains(systemLocale)) {
            langCode = systemLocale;
            _currentLocale = Locale(langCode);
            await prefs.setString('ui_locale', langCode);
          }
        }
      } catch (_) {}
    }

    await loadTranslations(langCode);
  }

  Future<void> fetchAvailableLanguages() async {
    try {
      final response = await _cfClient.client.get('/api/languages');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final List<String> sortedIds = [];
        final Map<String, String> nameMap = {};

        bool hasEn = false;
        for (var lang in data) {
          final id = lang['id'].toString().toLowerCase();
          final name = lang['name'].toString();
          nameMap[id] = name;
          if (id == 'en') {
            hasEn = true;
          } else {
            sortedIds.add(id);
          }
        }

        _availableUILanguages = hasEn ? ['en', ...sortedIds] : sortedIds;
        _languageNames.clear();
        _languageNames.addAll(nameMap);
        notifyListeners();
      }
    } catch (e) {
      AppLogger.log('Translation: Failed to fetch languages from Cloudflare: $e');
    }
  }

  Future<void> loadTranslations(String langCode) async {
    final lc = langCode.toLowerCase();
    _translations = Map<String, String>.from(_englishFallbacks);
    if (lc == 'en') return;

    try {
      final data = await _fetchFromCloudflare(lc);
      if (data.isNotEmpty) {
        data.forEach((key, value) {
          _translations[key] = value;
        });
      }
    } catch (e) {
      AppLogger.log('Translation: Cloudflare fetch failed for $lc: $e');
    }
  }

  Future<Map<String, String>> _fetchFromCloudflare(String langCode) async {
    try {
      final response = await _cfClient.client.get('/api/translations/$langCode');
      if (response.statusCode == 200) {
        return Map<String, String>.from(response.data);
      }
    } catch (e) {
      AppLogger.log('Error fetching translations: $e');
    }
    return {};
  }

  void setLocale(Locale locale, {bool persistGlobal = true}) async {
    if (_currentLocale == locale) return;

    _currentLocale = locale;
    await loadTranslations(locale.languageCode);
    notifyListeners();

    if (persistGlobal) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ui_locale', locale.languageCode);
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
