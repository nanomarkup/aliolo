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

  static const Map<String, Map<String, String>> _localizedFallbacks = {
    'en': {
      'documentation': 'Documentation',
      'show_documentation_btn': 'Show Documentation Button',
      'show_documentation_btn_desc': 'Display a help icon in the top navigation bar',
      'support_and_management': 'Support & About',
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
      'onboarding_1_title': 'Welcome to Aliolo',
      'onboarding_1_desc': 'Your personal visual learning assistant for mastering any subject.',
      'onboarding_2_title': 'Smart Learning',
      'onboarding_2_desc': 'Interactive flashcards with images and audio for faster memorization.',
      'onboarding_3_title': 'Track Progress',
      'onboarding_3_desc': 'Build your daily streak and watch your knowledge grow every day.',
      'onboarding_4_title': 'Connect & Share',
      'onboarding_4_desc': 'Learn together with friends and compete on the global leaderboard.',
      'onboarding_5_title': 'Cloud Sync',
      'onboarding_5_desc': 'Your data is always with you, synced across web and desktop apps.',
      'onboarding_6_title': 'Create Content',
      'onboarding_6_desc': 'Easily add your own subjects and share them with the community.',
      'onboarding_skip': 'Skip',
      'onboarding_next': 'Next',
      'onboarding_get_started': 'Get Started',
    },
    'id': {
      'documentation': 'Dokumentasi',
      'show_documentation_btn': 'Tampilkan Tombol Dokumentasi',
      'show_documentation_btn_desc': 'Menampilkan ikon bantuan di bilah navigasi atas',
      'support_and_management': 'Dukungan & Tentang',
    },
    'bg': {
      'documentation': 'Документация',
      'show_documentation_btn': 'Показване на бутона за документация',
      'show_documentation_btn_desc': 'Показване на икона за помощ в горната лента за навигация',
      'support_and_management': 'Поддръжка и Информация',
    },
    'cs': {
      'documentation': 'Dokumentace',
      'show_documentation_btn': 'Zobrazit tlačítko dokumentace',
      'show_documentation_btn_desc': 'Zobrazit ikonu nápovědy v horní navigační liště',
      'support_and_management': 'Podpora a o aplikaci',
    },
    'da': {
      'documentation': 'Dokumentation',
      'show_documentation_btn': 'Vis dokumentationsknap',
      'show_documentation_btn_desc': 'Vis et hjælpeikon i den øverste navigationslinje',
      'support_and_management': 'Support og Om',
    },
    'de': {
      'documentation': 'Dokumentation',
      'show_documentation_btn': 'Dokumentations-Schaltfläche anzeigen',
      'show_documentation_btn_desc': 'Ein Hilfe-Symbol in der oberen Navigationsleiste anzeigen',
      'support_and_management': 'Support & Über uns',
    },
    'et': {
      'documentation': 'Dokumentatsioon',
      'show_documentation_btn': 'Näita dokumentatsiooni nuppu',
      'show_documentation_btn_desc': 'Kuva abiikoon ülemisel navigeerimisribal',
      'support_and_management': 'Tugi ja teave',
    },
    'es': {
      'documentation': 'Documentación',
      'show_documentation_btn': 'Mostrar botón de documentación',
      'show_documentation_btn_desc': 'Mostrar un icono de ayuda en la barra de navegación superior',
      'support_and_management': 'Soporte y Acerca de',
    },
    'fr': {
      'documentation': 'Documentation',
      'show_documentation_btn': 'Afficher le bouton de documentation',
      'show_documentation_btn_desc': 'Afficher une icône d\'aide dans la barre de navigation supérieure',
      'support_and_management': 'Support et À propos',
    },
    'ga': {
      'documentation': 'Doiciméadúchán',
      'show_documentation_btn': 'Taispeáin Cnaipe Doiciméadúcháin',
      'show_documentation_btn_desc': 'Taispeáin deilbhín cabhrach sa bharra nascleanúna uachtarach',
      'support_and_management': 'Tacaíocht & Maidir le',
    },
    'hr': {
      'documentation': 'Dokumentacija',
      'show_documentation_btn': 'Prikaži gumb za dokumentaciju',
      'show_documentation_btn_desc': 'Prikaži ikonu pomoći u gornjoj navigacijskoj traci',
      'support_and_management': 'Podrška i O aplikaciji',
    },
    'it': {
      'documentation': 'Documentazione',
      'show_documentation_btn': 'Mostra pulsante documentazione',
      'show_documentation_btn_desc': 'Mostra un\'icona di aiuto nella barra di navigazione superiore',
      'support_and_management': 'Supporto e Informazioni',
    },
    'lv': {
      'documentation': 'Dokumentācija',
      'show_documentation_btn': 'Rādīt dokumentācijas pogu',
      'show_documentation_btn_desc': 'Rādīt palīdzības ikonu augšējā navigācijas joslā',
      'support_and_management': 'Atbalsts un Par',
    },
    'lt': {
      'documentation': 'Dokumentacija',
      'show_documentation_btn': 'Rodyti dokumentacijos mygtuką',
      'show_documentation_btn_desc': 'Rodyti pagalbos piktogramą viršutinėje navigacijos juostoje',
      'support_and_management': 'Palaikymas ir Apie',
    },
    'hu': {
      'documentation': 'Dokumentáció',
      'show_documentation_btn': 'Dokumentáció gomb megjelenítése',
      'show_documentation_btn_desc': 'Súgó ikon megjelenítése a felső navigációs sávban',
      'support_and_management': 'Támogatás és Névjegy',
    },
    'mt': {
      'documentation': 'Dokumentazzjoni',
      'show_documentation_btn': 'Uri l-buttuna tad-dokumentazzjoni',
      'show_documentation_btn_desc': 'Uri ikona tal-għajnuna fil-bar tan-navigazzjoni ta\' fuq',
      'support_and_management': 'Appoġġ u Dwar',
    },
    'nl': {
      'documentation': 'Documentatie',
      'show_documentation_btn': 'Documentatieknop weergeven',
      'show_documentation_btn_desc': 'Help-icoon weergeven in de bovenste navigatiebalk',
      'support_and_management': 'Ondersteuning & Over',
    },
    'pl': {
      'documentation': 'Dokumentacja',
      'show_documentation_btn': 'Pokaż przycisk dokumentacji',
      'show_documentation_btn_desc': 'Wyświetl ikonę pomocy w górnym pasku nawigacyjnym',
      'support_and_management': 'Wsparcie i informacje',
    },
    'pt': {
      'documentation': 'Documentação',
      'show_documentation_btn': 'Mostrar botão de documentação',
      'show_documentation_btn_desc': 'Exibir um ícone de ajuda na barra de navigação superior',
      'support_and_management': 'Suporte e Sobre',
    },
    'ro': {
      'documentation': 'Documentație',
      'show_documentation_btn': 'Afișează butonul de documentație',
      'show_documentation_btn_desc': 'Afișează o pictogramă de ajutor în bara de navigare superioară',
      'support_and_management': 'Suport și Despre',
    },
    'sk': {
      'documentation': 'Dokumentácia',
      'show_documentation_btn': 'Zobraziť tlačidlo dokumentácie',
      'show_documentation_btn_desc': 'Zobraziť ikonu pomocníka v hornej navigačnej lište',
      'support_and_management': 'Podpora a O aplikácii',
    },
    'sl': {
      'documentation': 'Dokumentacija',
      'show_documentation_btn': 'Prikaži gumb za dokumentacijo',
      'show_documentation_btn_desc': 'Prikaži ikono pomoči v zgornji navigacijski vrstici',
      'support_and_management': 'Podpora in O aplikaciji',
    },
    'fi': {
      'documentation': 'Dokumentaatio',
      'show_documentation_btn': 'Näytä dokumentaatiopainike',
      'show_documentation_btn_desc': 'Näytä ohjekuvake yläreunan navigointipalkissa',
      'support_and_management': 'Tuki ja Tietoja',
    },
    'sv': {
      'documentation': 'Dokumentation',
      'show_documentation_btn': 'Visa dokumentationsknapp',
      'show_documentation_btn_desc': 'Visa en hjälpikon i det övre navigeringsfältet',
      'support_and_management': 'Support och Om',
    },
    'tl': {
      'documentation': 'Dokumentasyon',
      'show_documentation_btn': 'Ipakita ang Button ng Dokumentasyon',
      'show_documentation_btn_desc': 'Ipakita ang icon ng tulong sa itaas na navigation bar',
      'support_and_management': 'Suporta at Tungkol',
    },
    'vi': {
      'documentation': 'Tài liệu',
      'show_documentation_btn': 'Hiển thị nút tài liệu',
      'show_documentation_btn_desc': 'Hiển thị biểu tượng trợ giúp trong thanh điều hướng trên cùng',
      'support_and_management': 'Hỗ trợ & Giới thiệu',
    },
    'tr': {
      'documentation': 'Dokümantasyon',
      'show_documentation_btn': 'Dokümantasyon Butonunu Göster',
      'show_documentation_btn_desc': 'Üst navigasyon çubuğunda bir yardım simgesi görüntüle',
      'support_and_management': 'Destek ve Hakkında',
    },
    'el': {
      'documentation': 'Τεκμηρίωση',
      'show_documentation_btn': 'Εμφάνιση κουμπιού τεκμηρίωσης',
      'show_documentation_btn_desc': 'Εμφάνιση εικονιδίου βοήθειας στην επάνω γραμμή πλοήγησης',
      'support_and_management': 'Υποστήριξη & Σχετικά',
    },
    'uk': {
      'documentation': 'Документація',
      'show_documentation_btn': 'Показати кнопку документації',
      'show_documentation_btn_desc': 'Відображати іконку допомоги у верхній навігаційній панелі',
      'support_and_management': 'Підтримка та Про програму',
    },
    'ar': {
      'documentation': 'التوثيق',
      'show_documentation_btn': 'عرض زر التوثيق',
      'show_documentation_btn_desc': 'عرض أيقونة المساعدة في شريط التنقل العلوي',
      'support_and_management': 'الدعم وعن التطبيق',
    },
    'hi': {
      'documentation': 'दस्तावेज़ीकरण',
      'show_documentation_btn': 'दस्तावेज़ीकरण बटन दिखाएं',
      'show_documentation_btn_desc': 'शीर्ष नेविगेशन बार में सहायता आइकन प्रदर्शित करें',
      'support_and_management': 'सहायता और जानकारी',
    },
    'zh': {
      'documentation': '文档',
      'show_documentation_btn': '显示文档按钮',
      'show_documentation_btn_desc': '在顶部导航栏显示帮助图标',
      'support_and_management': '支持与关于',
    },
    'ja': {
      'documentation': 'ドキュメント',
      'show_documentation_btn': 'ドキュメントボタンを表示',
      'show_documentation_btn_desc': '上部のナビゲーションバーにヘルプアイコンを表示',
      'support_and_management': 'サポートと詳細',
    },
    'ko': {
      'documentation': '문서',
      'show_documentation_btn': '문서 버튼 표시',
      'show_documentation_btn_desc': '상단 내비게이션 바에 도움말 아이콘 표시',
      'support_and_management': '지원 및 정보',
    },
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
    final lang = _currentLocale.languageCode.toLowerCase();
    String value =
        _translations[key] ??
        _localizedFallbacks[lang]?[key] ??
        _localizedFallbacks['en']?[key] ??
        key;
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
