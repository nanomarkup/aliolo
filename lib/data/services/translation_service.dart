import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:aliolo/core/utils/io_utils.dart' if (dart.library.html) 'package:aliolo/core/utils/file_stub.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
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
  
  // Hardcoded fallback list - Sorted by Native Name (English first)
  static const List<String> _fallbackUILanguages = [
    'en', 'id', 'bg', 'cs', 'da', 'de', 'et', 'es', 'fr', 'ga', 'hr', 'it', 'lv', 'lt', 'hu', 'mt', 'nl', 'pl', 'pt', 'ro', 'sk', 'sl', 'fi', 'sv', 'tl', 'vi', 'tr', 'el', 'uk', 'ar', 'hi', 'zh', 'ja', 'ko'
  ];

  List<String> _availableUILanguages = List.from(_fallbackUILanguages);
  List<String> get availableUILanguages => _availableUILanguages;

  final Map<String, String> _languageNames = {};

  dynamic _langDir;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedLocale = prefs.getString('ui_locale');

    if (!kIsWeb) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final alioloDir = dynamicDirectory(p.join(dir.path, '.aliolo'));
        _langDir = dynamicDirectory(p.join(alioloDir.path, 'lang'));

        if (!await _langDir!.exists()) {
          await _langDir!.create(recursive: true);
        }
      } catch (e) {
        print('Translation: FS init error: $e');
      }
    }

    // 1. Fetch languages from DB
    await fetchAvailableLanguages();

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
      // Fallback names for getLanguageName logic if DB fails
    }
  }

  Future<void> loadTranslations(String langCode) async {
    const String assetsPrefix = 'assets/lang/';
    final lc = langCode.toLowerCase();

    // 1. ALWAYS Load internal English as base fallback from assets
    try {
      final String baseJson = await rootBundle.loadString(
        '${assetsPrefix}en.json',
      );
      _translations = Map<String, String>.from(jsonDecode(baseJson));
    } catch (e) {
      print('Translation: Failed to load base English: $e');
    }

    // 2. Try to fetch the selected language from the DATABASE
    try {
      final dbData = await _fetchFromDb(lc);
      if (dbData.isNotEmpty) {
        dbData.forEach((key, value) {
          _translations[key] = value;
        });
        // Cache to local file system for offline use
        if (!kIsWeb && _langDir != null) {
          final file = dynamicFile(p.join(_langDir!.path, '$lc.json'));
          await file.writeAsString(jsonEncode(dbData));
        }
        return; // Success, skip asset loading
      }
    } catch (e) {
      print('Translation: DB fetch failed for $lc, falling back: $e');
    }

    // 3. FALLBACK: Try internal bundled asset
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

    // 4. FALLBACK: Try external folder (if offline and previously cached)
    if (!kIsWeb && _langDir != null) {
      final externalFile = dynamicFile(p.join(_langDir!.path, '$lc.json'));
      if (await externalFile.exists()) {
        try {
          final String content = await externalFile.readAsString();
          Map<String, dynamic> externalMap = jsonDecode(content);
          externalMap.forEach((key, value) {
            _translations[key] = value.toString();
          });
        } catch (_) {}
      }
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

  /// UTILITY: Call this to upload all your local JSON files to Supabase.
  /// You can call this from a dev screen or just once during maintenance.
  Future<void> syncLocalTranslationsToDb() async {
    for (var lang in _availableUILanguages) {
      try {
        final String jsonString = await rootBundle.loadString(
          'assets/lang/$lang.json',
        );
        final Map<String, dynamic> map = jsonDecode(jsonString);

        final List<Map<String, dynamic>> rows = [];
        map.forEach((key, value) {
          rows.add({
            'key': key,
            'lang': lang,
            'value': value.toString(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        });

        if (rows.isNotEmpty) {
          await _supabase.from('ui_translations').upsert(
            rows,
            onConflict: 'key,lang',
          );
          print('Synced $lang to DB (${rows.length} keys)');
        }
      } catch (e) {
        print('Failed to sync $lang: $e');
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
    String value = _translations[key] ?? key;
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
      if (dbData.isNotEmpty) {
        _languageMaps[langCode] = dbData;
      } else {
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
    }
    return _languageMaps[langCode]?[key] ?? key;
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
