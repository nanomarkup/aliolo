import 'package:aliolo/core/utils/io_utils.dart' if (dart.library.html) 'package:aliolo/core/utils/file_stub.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestingLanguage {
  final String code;
  final String name;
  final String nativeName;

  const TestingLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
  });
}

class TestingLanguageService extends ChangeNotifier {
  static final TestingLanguageService _instance =
      TestingLanguageService._internal();
  factory TestingLanguageService() => _instance;
  TestingLanguageService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;

  // Hardcoded fallback list
  static const List<TestingLanguage> _fallbackLanguages = [
    TestingLanguage(code: 'id', name: 'Indonesian', nativeName: 'Bahasa Indonesia'),
    TestingLanguage(code: 'bg', name: 'Bulgarian', nativeName: 'Български'),
    TestingLanguage(code: 'cs', name: 'Czech', nativeName: 'Čeština'),
    TestingLanguage(code: 'da', name: 'Danish', nativeName: 'Dansk'),
    TestingLanguage(code: 'de', name: 'German', nativeName: 'Deutsch'),
    TestingLanguage(code: 'et', name: 'Estonian', nativeName: 'Eesti'),
    TestingLanguage(code: 'en', name: 'English', nativeName: 'English'),
    TestingLanguage(code: 'es', name: 'Spanish', nativeName: 'Español'),
    TestingLanguage(code: 'fr', name: 'French', nativeName: 'Français'),
    TestingLanguage(code: 'ga', name: 'Irish', nativeName: 'Gaeilge'),
    TestingLanguage(code: 'hr', name: 'Croatian', nativeName: 'Hrvatski'),
    TestingLanguage(code: 'it', name: 'Italian', nativeName: 'Italiano'),
    TestingLanguage(code: 'lv', name: 'Latvian', nativeName: 'Latviešu'),
    TestingLanguage(code: 'lt', name: 'Lithuanian', nativeName: 'Lietuvių'),
    TestingLanguage(code: 'hu', name: 'Hungarian', nativeName: 'Magyar'),
    TestingLanguage(code: 'mt', name: 'Maltese', nativeName: 'Malti'),
    TestingLanguage(code: 'nl', name: 'Dutch', nativeName: 'Nederlands'),
    TestingLanguage(code: 'pl', name: 'Polish', nativeName: 'Polski'),
    TestingLanguage(code: 'pt', name: 'Portuguese', nativeName: 'Português'),
    TestingLanguage(code: 'ro', name: 'Romanian', nativeName: 'Română'),
    TestingLanguage(code: 'sk', name: 'Slovak', nativeName: 'Slovenčina'),
    TestingLanguage(code: 'sl', name: 'Slovenščina', nativeName: 'Slovenščina'),
    TestingLanguage(code: 'fi', name: 'Finnish', nativeName: 'Suomi'),
    TestingLanguage(code: 'sv', name: 'Swedish', nativeName: 'Svenska'),
    TestingLanguage(code: 'tl', name: 'Tagalog', nativeName: 'Tagalog'),
    TestingLanguage(code: 'vi', name: 'Vietnamese', nativeName: 'Tiếng Việt'),
    TestingLanguage(code: 'tr', name: 'Turkish', nativeName: 'Türkçe'),
    TestingLanguage(code: 'el', name: 'Greek', nativeName: 'Ελληνικά'),
    TestingLanguage(code: 'uk', name: 'Ukrainian', nativeName: 'Українська'),
    TestingLanguage(code: 'ar', name: 'Arabic', nativeName: 'العربية'),
    TestingLanguage(code: 'hi', name: 'Hindi', nativeName: 'हिन्दी'),
    TestingLanguage(code: 'zh', name: 'Chinese', nativeName: '中文'),
    TestingLanguage(code: 'ja', name: 'Japanese', nativeName: '日本語'),
    TestingLanguage(code: 'ko', name: 'Korean', nativeName: '한국어'),
  ];

  List<TestingLanguage> _allLanguages = List.from(_fallbackLanguages);
  List<TestingLanguage> get allLanguages => _allLanguages;

  List<String> _activeLanguageCodes = ['en'];
  List<String> get activeLanguageCodes => _activeLanguageCodes;

  final ValueNotifier<String> currentLanguageCode = ValueNotifier<String>('en');

  late dynamic _settingsFile;

  Future<void> init() async {
    // 1. Fetch from DB
    await fetchLanguagesFromDb();

    // 2. Load last used learning language
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastLang = prefs.getString('last_testing_lang') ?? 'en';
      currentLanguageCode.value = lastLang;
    } catch (e) {
      debugPrint('Error loading SharedPreferences for testing language: $e');
    }

    if (kIsWeb) return;
    
    final dir = await getApplicationDocumentsDirectory();
    final alioloDir = dynamicDirectory(p.join(dir.path, '.aliolo'));
    if (!await alioloDir.exists()) await alioloDir.create(recursive: true);

    _settingsFile = dynamicFile(p.join(alioloDir.path, 'content_langs.json'));

    if (await _settingsFile.exists()) {
      try {
        final content = await _settingsFile.readAsString();
        final List<dynamic> data = jsonDecode(content);
        _activeLanguageCodes = data.map((e) => e.toString()).toList();
      } catch (e) {
        print('Error loading content languages: $e');
      }
    } else {
      await _save();
    }
  }

  Future<void> updateCurrentLanguage(String code) async {
    if (currentLanguageCode.value == code) return;
    currentLanguageCode.value = code;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_testing_lang', code);
    } catch (e) {
      debugPrint('Error saving SharedPreferences for testing language: $e');
    }
  }

  Future<void> fetchLanguagesFromDb() async {
    try {
      final List<dynamic> data = await _supabase
          .from('languages')
          .select('id, name')
          .order('name');
      
      if (data.isNotEmpty) {
        _allLanguages = data.map((e) => TestingLanguage(
          code: e['id'].toString().toLowerCase(),
          name: e['name'].toString(), // We use nativeName as primary name in DB
          nativeName: e['name'].toString(),
        )).toList();
        notifyListeners();
      }
    } catch (e) {
      print('TestingLanguageService: DB fetch failed: $e');
    }
  }

  Future<void> toggleLanguage(String code) async {
    if (_activeLanguageCodes.contains(code)) {
      if (_activeLanguageCodes.length > 1) {
        _activeLanguageCodes.remove(code);
      }
    } else {
      _activeLanguageCodes.add(code);
    }
    await _save();
    notifyListeners();
  }

  Future<void> setActiveLanguages(List<String> codes) async {
    final cleanCodes = codes.map((c) => c.toLowerCase()).toSet().toList();
    if (cleanCodes.isEmpty) return;

    _activeLanguageCodes = cleanCodes;
    await _save();
    notifyListeners();
  }

  void addActiveLanguages(List<String> codes) {
    final newSet = _activeLanguageCodes.map((c) => c.toLowerCase()).toSet();
    newSet.addAll(codes.map((c) => c.toLowerCase()));
    if (newSet.length != _activeLanguageCodes.length) {
      _activeLanguageCodes = newSet.toList();
      _save();
      notifyListeners();
    }
  }

  Future<void> _save() async {
    if (kIsWeb) return;
    await _settingsFile.writeAsString(jsonEncode(_activeLanguageCodes));
  }

  Future<void> resetToDefault() async {
    _activeLanguageCodes = ['en'];
    await _save();
    notifyListeners();
  }

  String getLanguageName(String code) {
    try {
      return _allLanguages
          .firstWhere((l) => l.code == code.toLowerCase())
          .nativeName;
    } catch (_) {
      return code.toUpperCase();
    }
  }
}
