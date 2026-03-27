import 'package:aliolo/core/utils/io_utils.dart' if (dart.library.html) 'package:aliolo/core/utils/file_stub.dart';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TranslationService extends ChangeNotifier {
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;

  Locale _currentLocale = const Locale('en');
  Locale get currentLocale => _currentLocale;

  Map<String, String> _translations = {};
  Map<String, String> _englishFallbacks = {};

  static const Map<String, String> _localFallbacks = {
    'documentation': 'Documentation',
    'show_documentation_btn': 'Show Documentation Button',
    'show_documentation_btn_desc': 'Display a help icon in the top navigation bar',
    'doc_welcome_title': 'Welcome to Aliolo',
    'doc_welcome_desc':
        'Aliolo is a visual learning platform designed to help you master subjects through flashcards and interactive testing.',
    'doc_flashcards_title': 'Visual Flashcards',
    'doc_flashcards_desc':
        'Each subject contains a set of cards with images and audio. You can browse through them to familiarize yourself with the content.',
    'doc_testing_title': 'Interactive Testing',
    'doc_testing_desc':
        'Challenge yourself with multiple-choice questions (MCQ). The app will automatically advance as you answer, helping you learn faster.',
    'doc_streaks_title': 'Streak System',
    'doc_streaks_desc':
        'Consistency is key! Complete your daily goal every day to build your streak. Don\'t miss a day, or the streak will reset.',
    'doc_goals_title': 'Daily Goals',
    'doc_goals_desc':
        'Set your daily card completion target in the settings. Changes to your goal take effect starting the next day.',
    'doc_sync_title': 'Cloud Sync',
    'doc_sync_desc':
        'Your progress is automatically synced to the cloud. You can switch between web and desktop versions without losing your streak.',
    'support_and_management': 'Support & About',
  };
  
  // Hardcoded fallback list - Sorted by Native Name (English first)
  static const List<String> _fallbackUILanguages = [
    'en', 'id', 'bg', 'cs', 'da', 'de', 'et', 'es', 'fr', 'ga', 'hr', 'it', 'lv', 'lt', 'hu', 'mt', 'nl', 'pl', 'pt', 'ro', 'sk', 'sl', 'fi', 'sv', 'tl', 'vi', 'tr', 'el', 'uk', 'ar', 'hi', 'zh', 'ja', 'ko'
  ];

  List<String> _availableUILanguages = List.from(_fallbackUILanguages);
  List<String> get availableUILanguages => _availableUILanguages;

  final Map<String, String> _languageNames = {};

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedLocale = prefs.getString('ui_locale');

    // 1. Fetch languages from DB
    await fetchAvailableLanguages();

    // 2. Load English fallbacks always
    _englishFallbacks = await _fetchFromDb('en');

    // Load saved locale or default to system language
    String langCode = 'en';
    if (savedLocale != null) {
      langCode = savedLocale;
      _currentLocale = Locale(langCode);
    } else {
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

  Future<void> fetchAvailableLanguages() async {
    try {
      final List<dynamic> data = await _supabase
          .from('languages')
          .select('id, name')
          .order('name');
      
      if (data.isNotEmpty) {
        final List<String> sortedIds = [];
        final Map<String, String> nameMap = {};
        
        // Always put English first if exists
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
      print('Translation: Failed to fetch languages from DB: $e');
    }
  }

  Future<void> loadTranslations(String langCode) async {
    final lc = langCode.toLowerCase();

    // Start with English fallbacks
    _translations = Map<String, String>.from(_englishFallbacks);

    if (lc == 'en') return;

    try {
      final dbData = await _fetchFromDb(lc);
      if (dbData.isNotEmpty) {
        dbData.forEach((key, value) {
          _translations[key] = value;
        });
      }
    } catch (e) {
      print('Translation: DB fetch failed for $lc: $e');
    }
  }

  Future<Map<String, String>> _fetchFromDb(String langCode) async {
    try {
      final List<dynamic> data = await _supabase
          .from('ui_translations')
          .select('key, value')
          .eq('lang', langCode);

      final Map<String, String> map = {};
      for (var item in data) {
        map[item['key'].toString()] = item['value'].toString();
      }
      return map;
    } catch (e) {
      return {};
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
    String value = _translations[key] ?? _localFallbacks[key] ?? key;
    if (args != null) {
      args.forEach((k, v) {
        value = value.replaceAll('{$k}', v);
      });
    }
    return value;
  }

  /// Translates a key into a specific language code.
  String translateInLanguage(String key, String langCode) {
    if (langCode.toLowerCase() == _currentLocale.languageCode.toLowerCase()) {
      return translate(key);
    }
    return key;
  }

  final Map<String, Map<String, String>> _languageMaps = {};

  Future<String> translateForLanguage(String key, String langCode) async {
    if (!_languageMaps.containsKey(langCode)) {
      final dbData = await _fetchFromDb(langCode);
      _languageMaps[langCode] = dbData;
    }
    return _languageMaps[langCode]?[key] ?? _englishFallbacks[key] ?? key;
  }

  String getLanguageName(String code) {
    final lc = code.toLowerCase();
    if (_languageNames.containsKey(lc)) {
      return _languageNames[lc]!;
    }

    switch (lc) {
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
      case 'zh': return '中文';
      case 'ja': return '日本語';
      case 'ko': return '한국어';
      case 'bg': return 'Български';
      case 'hr': return 'Hrvatski';
      case 'cs': return 'Čeština';
      case 'da': return 'Dansk';
      case 'et': return 'Eesti';
      case 'fi': return 'Suomi';
      case 'hu': return 'Magyar';
      case 'ga': return 'Gaeilge';
      case 'lv': return 'Latviešu';
      case 'lt': return 'Lietuvių';
      case 'mt': return 'Malti';
      case 'ro': return 'Română';
      case 'sk': return 'Slovenčina';
      case 'sl': return 'Slovenščina';
      case 'sv': return 'Svenska';
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
