import 'package:aliolo/core/utils/io_utils.dart' if (dart.library.html) 'package:aliolo/core/utils/file_stub.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

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

  // Sorted alphabetically by nativeName string values
  final List<TestingLanguage> allLanguages = const [
    TestingLanguage(
      code: 'id',
      name: 'Indonesian',
      nativeName: 'Bahasa Indonesia',
    ),
    TestingLanguage(code: 'de', name: 'German', nativeName: 'Deutsch'),
    TestingLanguage(code: 'en', name: 'English', nativeName: 'English'),
    TestingLanguage(code: 'es', name: 'Spanish', nativeName: 'Español'),
    TestingLanguage(code: 'fa', name: 'Persian', nativeName: 'Farsi'),
    TestingLanguage(code: 'fr', name: 'French', nativeName: 'Français'),
    TestingLanguage(code: 'it', name: 'Italian', nativeName: 'Italiano'),
    TestingLanguage(code: 'sw', name: 'Swahili', nativeName: 'Kiswahili'),
    TestingLanguage(code: 'nl', name: 'Dutch', nativeName: 'Nederlands'),
    TestingLanguage(code: 'pl', name: 'Polish', nativeName: 'Polski'),
    TestingLanguage(code: 'pt', name: 'Portuguese', nativeName: 'Português'),
    TestingLanguage(code: 'tl', name: 'Tagalog', nativeName: 'Tagalog'),
    TestingLanguage(code: 'vi', name: 'Vietnamese', nativeName: 'Tiếng Việt'),
    TestingLanguage(code: 'tr', name: 'Turkish', nativeName: 'Türkçe'),
    TestingLanguage(code: 'el', name: 'Greek', nativeName: 'Ελληνικά'),
    TestingLanguage(code: 'uk', name: 'Ukrainian', nativeName: 'Українська'),
    TestingLanguage(code: 'ar', name: 'Arabic', nativeName: 'العربية'),
    TestingLanguage(code: 'ur', name: 'Urdu', nativeName: 'اردو'),
    TestingLanguage(code: 'bn', name: 'Bengali', nativeName: 'বাংলা'),
    TestingLanguage(code: 'pa', name: 'Punjabi', nativeName: 'ਪੰਜਾਬੀ'),
    TestingLanguage(code: 'hi', name: 'Hindi', nativeName: 'हिन्दी'),
    TestingLanguage(code: 'mr', name: 'Marathi', nativeName: 'мраठी'),
    TestingLanguage(code: 'te', name: 'Telugu', nativeName: 'తెలుగు'),
    TestingLanguage(code: 'ta', name: 'Tamil', nativeName: 'தமிழ்'),
    TestingLanguage(code: 'th', name: 'Thai', nativeName: 'ไทย'),
    TestingLanguage(code: 'zh', name: 'Chinese', nativeName: '中文'),
    TestingLanguage(code: 'ja', name: 'Japanese', nativeName: '日本語'),
    TestingLanguage(code: 'ko', name: 'Korean', nativeName: '한국어'),
  ];

  List<String> _activeLanguageCodes = ['en'];
  List<String> get activeLanguageCodes => _activeLanguageCodes;

  late dynamic _settingsFile;

  Future<void> init() async {
    if (kIsWeb) {
      // On web, we start with default but addActiveLanguages will work in-memory
      return;
    }
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
    final newSet = Set<String>.from(_activeLanguageCodes);
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
      return allLanguages
          .firstWhere((l) => l.code == code.toLowerCase())
          .nativeName;
    } catch (_) {
      return code.toUpperCase();
    }
  }
}
