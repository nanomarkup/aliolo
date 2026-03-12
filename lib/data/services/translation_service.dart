import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class TranslationService extends ChangeNotifier {
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();

  Locale _currentLocale = const Locale('en');
  Locale get currentLocale => _currentLocale;

  Map<String, String> _translations = {};
  List<String> _availableUILanguages = ['en'];

  List<String> get availableUILanguages => _availableUILanguages;

  late Directory _langDir;

  Future<void> init() async {
    if (kIsWeb) {
      _availableUILanguages = [
        'en', 'uk', 'es', 'fr', 'de', 'it', 'pt', 'pl', 'nl', 'tr', 
        'vi', 'tl', 'id', 'el', 'ar', 'hi', 'zh', 'ja', 'ko'
      ];
      await loadTranslations('en');
      return;
    }
    final dir = await getApplicationDocumentsDirectory();
    final alioloDir = Directory(p.join(dir.path, '.aliolo'));
    _langDir = Directory(p.join(alioloDir.path, 'lang'));
    
    if (!await _langDir.exists()) {
      await _langDir.create(recursive: true);
    }

    // List of all supported UI languages (matching assets/lang/*.json)
    final List<String> bundledLangs = [
      'en', 'uk', 'es', 'fr', 'de', 'it', 'pt', 'pl', 'nl', 'tr', 
      'vi', 'tl', 'id', 'el', 'ar', 'hi', 'zh', 'ja', 'ko'
    ];

    // Copy all bundled assets to external folder if they don't exist
    for (var lang in bundledLangs) {
      final externalFile = File(p.join(_langDir.path, '$lang.json'));
      if (!await externalFile.exists()) {
        await _copyAssetToExternal(lang);
      }
    }

    // 1. Scan for available languages in the external folder
    await _refreshAvailableLanguages();

    // 2. Load saved locale or default to system language
    final settingsFile = File(p.join(alioloDir.path, 'ui_settings.json'));
    String langCode = 'en';
    if (await settingsFile.exists()) {
      try {
        final data = jsonDecode(await settingsFile.readAsString());
        if (data['locale'] != null) {
          langCode = data['locale'];
          _currentLocale = Locale(langCode);
        }
      } catch (_) {}
    } else {
      // First run: Guess from system
      try {
        final String systemLocale = Platform.localeName.split('_')[0].toLowerCase();
        if (_availableUILanguages.contains(systemLocale)) {
          langCode = systemLocale;
          _currentLocale = Locale(langCode);
          // Persist the guessed language
          await settingsFile.writeAsString(jsonEncode({'locale': langCode}));
        }
      } catch (_) {}
    }
    
    await loadTranslations(langCode);
  }

  Future<void> _copyAssetToExternal(String langCode) async {
    try {
      final data = await rootBundle.loadString('assets/lang/$langCode.json');
      final file = File(p.join(_langDir.path, '$langCode.json'));
      await file.writeAsString(data);
    } catch (e) {
      print('Error copying asset $langCode: $e');
    }
  }

  Future<void> _refreshAvailableLanguages() async {
    if (!await _langDir.exists()) return;
    
    final List<String> codes = [];
    final entities = await _langDir.list().toList();
    for (var entity in entities) {
      if (entity is File && entity.path.endsWith('.json')) {
        codes.add(p.basenameWithoutExtension(entity.path).toLowerCase());
      }
    }
    
    if (codes.isEmpty) codes.add('en');
    _availableUILanguages = codes..sort();
  }

  Future<void> loadTranslations(String langCode) async {
    final String assetsPrefix = kIsWeb ? 'assets/assets/lang/' : 'assets/lang/';
    
    // 1. Load internal English as base fallback
    try {
      final String baseJson = await rootBundle.loadString('${assetsPrefix}en.json');
      _translations = Map<String, String>.from(jsonDecode(baseJson));
    } catch (e) {
      print('Translation: Failed to load base English: $e');
    }

    if (kIsWeb) {
      if (langCode != 'en') {
        try {
          final String assetJson = await rootBundle.loadString('${assetsPrefix}$langCode.json');
          Map<String, dynamic> assetMap = jsonDecode(assetJson);
          assetMap.forEach((key, value) {
            _translations[key] = value.toString();
          });
        } catch (e) {
          print('Translation: Failed to load Web asset $langCode: $e');
        }
      }
      return;
    }

    // 2. Try to load selected language from external folder (Non-Web)
    final externalFile = File(p.join(_langDir.path, '$langCode.json'));
    if (await externalFile.exists()) {
      try {
        final String content = await externalFile.readAsString();
        Map<String, dynamic> externalMap = jsonDecode(content);
        externalMap.forEach((key, value) {
          _translations[key] = value.toString();
        });
      } catch (e) {
        print('Error loading external translation $langCode: $e');
      }
    } else if (langCode != 'en') {
      try {
        final String assetJson = await rootBundle.loadString('${assetsPrefix}$langCode.json');
        Map<String, dynamic> assetMap = jsonDecode(assetJson);
        assetMap.forEach((key, value) {
          _translations[key] = value.toString();
        });
      } catch (_) {}
    }
  }

  void setLocale(Locale locale, {bool persistGlobal = true}) async {
    if (_currentLocale == locale) return;
    
    _currentLocale = locale;
    await loadTranslations(locale.languageCode);
    notifyListeners();
    
    if (persistGlobal && !kIsWeb) {
      final dir = await getApplicationDocumentsDirectory();
      final alioloDir = Directory(p.join(dir.path, '.aliolo'));
      if (!await alioloDir.exists()) await alioloDir.create(recursive: true);
      final file = File(p.join(alioloDir.path, 'ui_settings.json'));
      await file.writeAsString(jsonEncode({'locale': locale.languageCode}));
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

  String getLanguageName(String code) {
    switch (code.toLowerCase()) {
      case 'en': return 'English';
      case 'uk': return 'Українська';
      case 'es': return 'Español';
      case 'fr': return 'Français';
      case 'de': return 'Deutsch';
      case 'it': return 'Italiano';
      case 'pt': return 'Português';
      case 'pl': return 'Polski';
      case 'nl': return 'Nederlands';
      case 'tr': return 'Türkçe';
      case 'vi': return 'Tiếng Việt';
      case 'tl': return 'Tagalog';
      case 'id': return 'Bahasa Indonesia';
      case 'el': return 'Ελληνικά';
      case 'ar': return 'العربية';
      case 'hi': return 'हिन्दी';
      case 'bn': return 'বাংলা';
      case 'zh': return '中文';
      case 'ja': return '日本語';
      case 'ko': return '한국어';
      default:
        if (code.isEmpty) return code;
        return code[0].toUpperCase() + code.substring(1);
    }
  }
}

extension TranslationExtension on BuildContext {
  String t(String key, {Map<String, String>? args}) => TranslationService().translate(key, args: args);
}
