import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class TranslationService extends ChangeNotifier {
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();

  Locale _currentLocale = const Locale('en');
  Locale get currentLocale => _currentLocale;

  Map<String, String> _translations = {};
  List<String> _availableUILanguages = [
    'en',
    'uk',
    'es',
    'fr',
    'de',
    'it',
    'pt',
    'pl',
    'nl',
    'tr',
    'vi',
    'tl',
    'id',
    'el',
    'ar',
    'hi',
    'zh',
    'ja',
    'ko',
  ];

  List<String> get availableUILanguages => _availableUILanguages;

  Directory? _langDir;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedLocale = prefs.getString('ui_locale');

    if (kIsWeb) {
      String langCode = savedLocale ?? 'en';
      _currentLocale = Locale(langCode);
      await loadTranslations(langCode);
      return;
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final alioloDir = Directory(p.join(dir.path, '.aliolo'));
      _langDir = Directory(p.join(alioloDir.path, 'lang'));

      if (!await _langDir!.exists()) {
        await _langDir!.create(recursive: true);
      }

      // Always sync all bundled assets to external folder to ensure updates are applied
      for (var lang in _availableUILanguages) {
        await _copyAssetToExternal(lang);
      }

      // 1. Scan for available languages in the external folder
      await _refreshAvailableLanguages();
    } catch (e) {
      print('Translation: Non-critical init error (FS): $e');
    }

    // 2. Load saved locale or default to system language
    String langCode = 'en';
    if (savedLocale != null) {
      langCode = savedLocale;
      _currentLocale = Locale(langCode);
    } else {
      // First run: Guess from system
      try {
        if (!kIsWeb) {
          final String systemLocale =
              Platform.localeName.split('_')[0].toLowerCase();
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

  Future<void> _copyAssetToExternal(String langCode) async {
    if (_langDir == null) return;
    try {
      final data = await rootBundle.loadString('assets/lang/$langCode.json');
      final file = File(p.join(_langDir!.path, '$langCode.json'));
      await file.writeAsString(data);
    } catch (e) {
      print('Error copying asset $langCode: $e');
    }
  }

  Future<void> _refreshAvailableLanguages() async {
    if (_langDir == null || !await _langDir!.exists()) return;

    final List<String> codes = [];
    final entities = await _langDir!.list().toList();
    for (var entity in entities) {
      if (entity is File && entity.path.endsWith('.json')) {
        codes.add(p.basenameWithoutExtension(entity.path).toLowerCase());
      }
    }

    if (codes.isNotEmpty) {
      _availableUILanguages = (codes..sort());
    }
  }

  Future<void> loadTranslations(String langCode) async {
    const String assetsPrefix = 'assets/lang/';
    final lc = langCode.toLowerCase();

    // 1. Load internal English as base fallback
    try {
      final String baseJson = await rootBundle.loadString(
        '${assetsPrefix}en.json',
      );
      _translations = Map<String, String>.from(jsonDecode(baseJson));
    } catch (e) {
      print('Translation: Failed to load base English: $e');
    }

    // 2. Merge internal selected language (if not English)
    if (lc != 'en') {
      try {
        final String assetJson = await rootBundle.loadString(
          '$assetsPrefix$lc.json',
        );
        Map<String, dynamic> assetMap = jsonDecode(assetJson);
        assetMap.forEach((key, value) {
          _translations[key] = value.toString();
        });
      } catch (_) {}
    }

    if (kIsWeb) return;

    // 3. Try to load selected language from external folder (Non-Web)
    if (_langDir != null) {
      final externalFile = File(p.join(_langDir!.path, '$lc.json'));
      if (await externalFile.exists()) {
        try {
          final String content = await externalFile.readAsString();
          Map<String, dynamic> externalMap = jsonDecode(content);
          externalMap.forEach((key, value) {
            _translations[key] = value.toString();
          });
        } catch (e) {
          print('Error loading external translation $lc: $e');
        }
      }
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
  }

  String translate(String key, {Map<String, String>? args}) {
    String text = _translations[key] ?? key;
    if (args != null) {
      args.forEach((k, v) {
        text = text.replaceAll('{$k}', v);
      });
    }
    return text;
  }

  final Map<String, Map<String, String>> _languageMaps = {};

  Future<String> translateForLanguage(String key, String langCode) async {
    if (!_languageMaps.containsKey(langCode)) {
      try {
        const String assetsPrefix = 'assets/lang/';
        final String jsonString = await rootBundle.loadString(
          '$assetsPrefix${langCode.toLowerCase()}.json',
        );
        _languageMaps[langCode] = Map<String, String>.from(
          jsonDecode(jsonString),
        );
      } catch (_) {
        _languageMaps[langCode] = {};
      }
    }
    return _languageMaps[langCode]?[key] ?? key;
  }

  String getLanguageName(String code) {
    switch (code.toLowerCase()) {
      case 'en':
        return 'English';
      case 'uk':
        return 'Українська';
      case 'es':
        return 'Español';
      case 'fr':
        return 'Français';
      case 'de':
        return 'Deutsch';
      case 'it':
        return 'Italiano';
      case 'pt':
        return 'Português';
      case 'pl':
        return 'Polski';
      case 'nl':
        return 'Nederlands';
      case 'tr':
        return 'Türkçe';
      case 'vi':
        return 'Tiếng Việt';
      case 'tl':
        return 'Tagalog';
      case 'id':
        return 'Bahasa Indonesia';
      case 'el':
        return 'Ελληνικά';
      case 'ar':
        return 'العربية';
      case 'hi':
        return 'हिन्दी';
      case 'bn':
        return 'বাংলা';
      case 'zh':
        return '中文';
      case 'ja':
        return '日本語';
      case 'ko':
        return '한국어';
      default:
        if (code.isEmpty) return code;
        return code[0].toUpperCase() + code.substring(1);
    }
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
