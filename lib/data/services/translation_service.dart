import 'package:aliolo/core/utils/io_utils.dart' if (dart.library.html) 'package:aliolo/core/utils/file_stub.dart';
import 'dart:io' show Platform;
import 'dart:convert' show json;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aliolo/core/network/cloudflare_client.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/core/utils/logger.dart';
import 'package:nanomarkup/nanomarkup.dart' as nano;

/// Runtime UI translation service.
///
/// This resolves chrome / app-label strings using local unhashed .nano files
/// as local assets and caches any fetched OTA translations locally in SharedPreferences.
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
    await _loadLocalEnglishFallback();

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

    // Fetch and apply OTA updates for the active locale in the background
    _checkForOTAUpdates(langCode).catchError((e) {
      AppLogger.log('Translation: background OTA check error: $e');
    });
  }

  Future<void> _loadLocalEnglishFallback() async {
    try {
      final localNano = await rootBundle.loadString('assets/translations/en.nano');
      final decoded = nano.decode(localNano);
      if (decoded is Map) {
        _englishFallbacks = decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
        if (_translations.isEmpty) {
          _translations = Map<String, String>.from(_englishFallbacks);
        }
      }
    } catch (e) {
      AppLogger.log('Translation: Failed to load local en.nano fallback: $e');
    }
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
      AppLogger.log('Translation: Failed to fetch languages: $e');
    }
  }

  Future<void> loadTranslations(String langCode) async {
    final lc = langCode.toLowerCase();
    
    // Start with English fallbacks
    _translations = Map<String, String>.from(_englishFallbacks);

    // Try to load cached OTA translations from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString('cached_translations_$lc');
    if (cachedJson != null) {
      try {
        final Map<String, dynamic> cachedMap = json.decode(cachedJson);
        cachedMap.forEach((k, v) {
          _translations[k] = v.toString();
        });
        AppLogger.log('Translation: Loaded cached OTA translations for $lc');
        return;
      } catch (e) {
        AppLogger.log('Translation: Failed to decode cached translations for $lc: $e');
      }
    }

    // Try to load local bundled asset translations
    try {
      final localNano = await rootBundle.loadString('assets/translations/$lc.nano');
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

  Future<void> _checkForOTAUpdates(String langCode) async {
    final lc = langCode.toLowerCase();
    try {
      final response = await _cfClient.client.get(
        '/storage/v1/object/public/aliolo-media/translations/manifest.json',
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> manifest = Map<String, dynamic>.from(response.data);
        final serverHash = manifest[lc]?.toString();
        if (serverHash == null) {
          AppLogger.log('Translation: No remote hash found in manifest for $lc');
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        final cachedHash = prefs.getString('cached_translations_hash_$lc');

        if (serverHash != cachedHash) {
          AppLogger.log('Translation: Fetching OTA translations for $lc (Server hash: $serverHash, Cached: $cachedHash)');
          final translationRes = await _cfClient.client.get(
            '/storage/v1/object/public/aliolo-media/translations/$lc.$serverHash.nano',
          );
          if (translationRes.statusCode == 200) {
            final nanoContent = translationRes.data.toString();
            final decoded = nano.decode(nanoContent);
            if (decoded is Map) {
              final Map<String, String> newTranslations = decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
              
              await prefs.setString('cached_translations_$lc', json.encode(newTranslations));
              await prefs.setString('cached_translations_hash_$lc', serverHash);

              _translations = Map<String, String>.from(_englishFallbacks);
              newTranslations.forEach((k, v) {
                _translations[k] = v;
              });
              notifyListeners();
              AppLogger.log('Translation: Successfully updated and cached OTA translations for $lc');
            }
          }
        }
      }
    } catch (e) {
      AppLogger.log('Translation: Failed to check/update OTA translations for $lc: $e');
    }
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

    _checkForOTAUpdates(locale.languageCode).catchError((e) {
      AppLogger.log('Translation: setLocale background OTA check error: $e');
    });
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

