import 'package:aliolo/core/utils/io_utils.dart' if (dart.library.html) 'package:aliolo/core/utils/file_stub.dart';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aliolo/core/network/cloudflare_client.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/core/utils/logger.dart';

class TranslationService extends ChangeNotifier {
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();

  final _cfClient = getIt<CloudflareHttpClient>();

  Locale _currentLocale = const Locale('en');
  Locale get currentLocale => _currentLocale;

  Map<String, String> _translations = {};
  Map<String, String> _englishFallbacks = {};

  static const Map<String, Map<String, String>> _localizedFallbacks = {
    'en': {
      'home': 'Home',
      'confirm': 'Confirm',
      'cancel': 'Cancel',
      'back': 'Back',
      'delete': 'Delete',
      'edit': 'Edit',
      'feedback': 'Feedback',
      'documentation': 'Documentation',
      'show_documentation_btn': 'Show Documentation Button',
      'show_documentation_btn_desc': 'Display a help icon in the top navigation bar',
      'support_and_management': 'Support & About',
      'account_and_management': 'Account & Management',
      'about_tagline': 'Learn Visually. Master Permanently.',
      'doc_tab_general': 'General',
      'doc_tab_learning': 'Practice',
      'doc_tab_creator': 'Creation',
      'doc_welcome_title': 'Welcome to Aliolo',
      'doc_welcome_desc':
          'Aliolo is a visual learning platform designed to help you master subjects through flashcards and interactive testing.',
      'doc_pillars_title': 'The 8 Core Pillars',
      'doc_pillars_desc':
          'All content in Aliolo is organized into 8 foundational pillars: Academic & Professional, World, Nature, Health, Humanities, Leisure, Engineering, and Other. These categories provide a structured framework for all subjects across the platform.',
      'doc_flashcards_desc':
          'Each subject contains a set of cards. While images and audio are supported, they are optional—content can be purely textual or dynamically generated.',
      'doc_testing_title': 'Interactive Testing',
      'doc_testing_desc':
          'Challenge yourself with multiple-choice questions (MCQ). The app will automatically advance as you answer, helping you learn faster.',
      'doc_study_modes_title': 'Adaptive Study Modes',
      'doc_study_modes_desc':
          'Aliolo supports various testing modes based on your content: Image-to-Text, Audio-to-Image, and Text-to-Audio. This multi-sensory approach ensures you master subjects from every angle.',
      'doc_math_title': 'Mathematical Subjects',
      'doc_math_desc':
          'Mathematical subjects use specialized engines to generate card visualizations in real-time. These subjects feature unique learning and testing modes tailored to specific mathematical concepts, ensuring a more effective practice environment.',
      'doc_lang_title': 'Learning Language',
      'doc_lang_desc':
          'Always select your preferred learning language in the top menu before selecting a subject. This ensures the correct audio and translations are loaded.',
      'doc_autoplay_title': 'Auto-Play Learning',
      'doc_autoplay_desc':
          'The app can automatically advance to the next card after you answer. Correct answers wait 1s, while incorrect ones wait 2s to let you review.',
      'doc_streaks_title': 'Streak System',
      'doc_streaks_desc':
          'Consistency is key! Complete your daily goal every day to build your streak. Don\'t miss a day, or the streak will reset.',
      'doc_goals_title': 'Daily Goals',
      'doc_goals_desc':
          'Set your daily card completion target in the settings. Changes to your goal take effect starting the next day.',
      'doc_sync_title': 'Cloud Sync',
      'doc_sync_desc':
          'Your progress is automatically synced to the cloud. You can switch between web and desktop versions without losing your streak.',
      'doc_leaderboard_title': 'Global Leaderboard',
      'doc_leaderboard_desc':
          'Compete with learners worldwide! Earn XP by completing card sessions and climb the ranks. Your position is updated in real-time as you master new subjects.',
      'doc_friends_title': 'Friends & Invitations',
      'doc_friends_desc':
          'Learning is better together! Invite friends to Aliolo through your profile. You can track each other\'s progress and stay motivated by seeing who maintains the longest streak.',
      'doc_public_title': 'Public vs Private',
      'doc_public_desc':
          'Subjects can be private (visible only to you) or public. Public content is shared with the entire Aliolo community, allowing everyone to discover and learn from your creations.',
      'doc_feedback_title': 'Feedback System',
      'doc_feedback_desc':
          'Help us improve! Use the feedback icon (Icons.feedback) on any Subject or Folder to report issues. You can also send general app feedback through the Support section.',
      'doc_collections_purpose_title': 'The Purpose of Collections',
      'doc_collections_purpose_desc':
          'Collections are curated paths that group Subjects together. When you start a session from a Collection, the system mixes cards from all included subjects to provide a randomized, comprehensive test.',
      'doc_filters_title': 'Search & Filters',
      'doc_filters_desc':
          'Quickly find content using the search bar. You can filter by Age Group (Early to Advanced) or narrow your view to specific Collections and Folders.',
      'doc_organization_title': 'Organizing Content',
      'doc_organization_desc':
          'Use Folders to group related Subjects together. You can also create Collections to organize Subjects into curated paths.',
      'doc_creation_title': 'Creating Subjects & Cards',
      'doc_creation_desc':
          'Create your own Subjects and add visual Flashcards. Each card supports an image and an optional audio file for pronunciation.',
      'doc_card_scope_title': 'Where Cards Live',
      'doc_card_scope_desc':
          'Cards are the building blocks of learning and always belong to a specific Subject. While you can organize Subjects into Folders or Collections, cards themselves must be created within a Subject.',
      'doc_localization_ui_title': 'Adding Translations',
      'doc_localization_ui_desc':
          'To add localized data, simply tap the language code icon (e.g., EN, ES, FR) in the editor header. This allows you to provide specific names, descriptions, and card content for each supported language. The "Global" tab serves as the primary fallback if no specific translation is provided.',
      'doc_json_title': 'JSON Localization',
      'doc_json_desc':
          'Advanced creators can use JSON data to provide localized names and descriptions, making subjects accessible across all supported languages.',
      'doc_localization_details_title': 'How Localization Works',
      'doc_localization_details_desc':
          'The "Global" language is your primary fallback—it can be any language you choose. If you provide specific translations (like English or Spanish), they will override the Global data only when a user selects that specific UI language.',
      'doc_media_title': 'Media Upload Limits',
      'doc_media_desc':
          'To ensure fast sync, keep images under 5MB and audio files under 10MB.',
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
      'next_daily_goal_desc': 'Target number of cards to master each day. Changes take effect tomorrow.',
      'learn_session_size_desc': 'Number of new cards to introduce in a single learning session.',
      'test_session_size_desc': 'Number of cards to review in a single testing session.',
      'options_count_desc': 'Number of multiple-choice answers displayed during tests.',
      'total_cards': 'Total Cards',
      'correct_answers': 'Correct Answers',
      'failed_answers': 'Failed',
      'maybe_later': 'Maybe Later',
      'finish': 'Finish',
      'dashboard_greeting': 'Hello',
      'billing_title': 'Checkout',
      'confirm_subscription': 'Confirm Subscription',
      'billing_disclaimer': 'Your subscription will automatically renew. You can cancel anytime in your account settings.',
      'subscribe_now': 'Subscribe Now',
      'premium_active': 'Aliolo Premium Active',
      'premium_active_desc': 'Manage your subscription or change plans',
      'premium_status_active': 'Subscription Active',
      'premium_expires_at': 'Expires on {date}',
      'premium_lifetime': 'Lifetime Access',
      'premium_upgrade_title': 'Upgrade to Premium',
      'premium_upgrade_desc': 'Unlock all features and math engines',
      'premium_manage': 'Manage',
      'premium_go': 'Go Premium',
      'premium_member': 'Premium Member',
      'manage_subscription': 'Manage Subscription',
      'session_complete_description': 'You have finished reviewing all cards in this session.',
      'source': 'Source',
      'level': 'Level',
      'card_level': 'Card Level',
      'level_help_text':
          'Tier 1 is most common/core, Tier 2 is well-known/secondary, and Tier 3 is niche/extended.',
      'level_tier_1': 'Tier 1',
      'level_tier_2': 'Tier 2',
      'level_tier_3': 'Tier 3',
      'filter_all': 'All',
      'filter_favorites': 'Favorites',
      'filter_my_subjects': 'My Subjects',
      'filter_public_library': 'Public Library',
      'age': 'Age',
      'age_all': 'All Ages',
      'age_0_6': 'Early (0-6)',
      'age_7_14': 'Primary (7-14)',
      'age_15_plus': 'Advanced (15+)',
      'filters': 'Filters',
      'category': 'Category',
    },
  };

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
    final lang = _currentLocale.languageCode.toLowerCase();
    
    String? value = _translations[key];
    if (value == null || value.trim().isEmpty) value = _englishFallbacks[key];
    if (value == null || value.trim().isEmpty) value = _localizedFallbacks[lang]?[key];
    if (value == null || value.trim().isEmpty) value = _localizedFallbacks['en']?[key];
    if (value == null || value.trim().isEmpty) value = key;

    if (args != null) {
      args.forEach((k, v) => value = value!.replaceAll('{$k}', v));
    }
    return value!;
  }

  String translateInLanguage(String key, String langCode) {
    if (langCode.toLowerCase() == _currentLocale.languageCode.toLowerCase()) return translate(key);
    return key;
  }

  final Map<String, Map<String, String>> _languageMaps = {};

  Future<String> translateForLanguage(String key, String langCode) async {
    if (!_languageMaps.containsKey(langCode)) {
      final data = await _fetchFromCloudflare(langCode);
      _languageMaps[langCode] = data;
    }
    
    String? value = _languageMaps[langCode]?[key];
    if (value == null || value.trim().isEmpty) value = _englishFallbacks[key];
    if (value == null || value.trim().isEmpty) value = _localizedFallbacks['en']?[key];
    if (value == null || value.trim().isEmpty) value = key;
    return value;
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
