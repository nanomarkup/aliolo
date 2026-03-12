import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class LearningLanguage {
  final String code;
  final String name;
  final String nativeName;

  const LearningLanguage({required this.code, required this.name, required this.nativeName});
}

class LearningLanguageService extends ChangeNotifier {
  static final LearningLanguageService _instance = LearningLanguageService._internal();
  factory LearningLanguageService() => _instance;
  LearningLanguageService._internal();

  // Sorted alphabetically by nativeName string values
  final List<LearningLanguage> allLanguages = const [
    LearningLanguage(code: 'id', name: 'Indonesian', nativeName: 'Bahasa Indonesia'),
    LearningLanguage(code: 'de', name: 'German', nativeName: 'Deutsch'),
    LearningLanguage(code: 'en', name: 'English', nativeName: 'English'),
    LearningLanguage(code: 'es', name: 'Spanish', nativeName: 'Español'),
    LearningLanguage(code: 'fa', name: 'Persian', nativeName: 'Farsi'),
    LearningLanguage(code: 'fr', name: 'French', nativeName: 'Français'),
    LearningLanguage(code: 'it', name: 'Italian', nativeName: 'Italiano'),
    LearningLanguage(code: 'sw', name: 'Swahili', nativeName: 'Kiswahili'),
    LearningLanguage(code: 'nl', name: 'Dutch', nativeName: 'Nederlands'),
    LearningLanguage(code: 'pl', name: 'Polish', nativeName: 'Polski'),
    LearningLanguage(code: 'pt', name: 'Portuguese', nativeName: 'Português'),
    LearningLanguage(code: 'tl', name: 'Tagalog', nativeName: 'Tagalog'),
    LearningLanguage(code: 'vi', name: 'Vietnamese', nativeName: 'Tiếng Việt'),
    LearningLanguage(code: 'tr', name: 'Turkish', nativeName: 'Türkçe'),
    LearningLanguage(code: 'el', name: 'Greek', nativeName: 'Ελληνικά'),
    LearningLanguage(code: 'uk', name: 'Ukrainian', nativeName: 'Українська'),
    LearningLanguage(code: 'ar', name: 'Arabic', nativeName: 'العربية'),
    LearningLanguage(code: 'ur', name: 'Urdu', nativeName: 'اردو'),
    LearningLanguage(code: 'bn', name: 'Bengali', nativeName: 'বাংলা'),
    LearningLanguage(code: 'pa', name: 'Punjabi', nativeName: 'ਪੰਜਾਬੀ'),
    LearningLanguage(code: 'hi', name: 'Hindi', nativeName: 'हिन्दी'),
    LearningLanguage(code: 'mr', name: 'Marathi', nativeName: 'мраठी'),
    LearningLanguage(code: 'te', name: 'Telugu', nativeName: 'తెలుగు'),
    LearningLanguage(code: 'ta', name: 'Tamil', nativeName: 'தமிழ்'),
    LearningLanguage(code: 'th', name: 'Thai', nativeName: 'ไทย'),
    LearningLanguage(code: 'zh', name: 'Chinese', nativeName: '中文'),
    LearningLanguage(code: 'ja', name: 'Japanese', nativeName: '日本語'),
    LearningLanguage(code: 'ko', name: 'Korean', nativeName: '한국어'),
  ];

  List<String> _activeLanguageCodes = ['en'];
  List<String> get activeLanguageCodes => _activeLanguageCodes;

  late File _settingsFile;

  Future<void> init() async {
    if (kIsWeb) return;
    final dir = await getApplicationDocumentsDirectory();
    final alioloDir = Directory(p.join(dir.path, '.aliolo'));
    if (!await alioloDir.exists()) await alioloDir.create(recursive: true);
    
    _settingsFile = File(p.join(alioloDir.path, 'content_langs.json'));
    
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
      return allLanguages.firstWhere((l) => l.code == code.toLowerCase()).nativeName;
    } catch (_) {
      return code.toUpperCase();
    }
  }
}
