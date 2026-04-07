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
      'account_and_management': 'Account & Management',
      'about_tagline': 'Learn Visually. Master Permanently.',
      'doc_tab_general': 'General',
      'doc_tab_learning': 'Learning & Testing',
      'doc_tab_creator': 'Creator Guide',
      'doc_welcome_title': 'Welcome to Aliolo',
      'doc_welcome_desc':
          'Aliolo is a visual learning platform designed to help you master subjects through flashcards and interactive testing.',
      'doc_pillars_title': 'The 8 Core Pillars',
      'doc_pillars_desc':
          'All content in Aliolo is organized into 8 foundational pillars: Academic & Professional, World, Nature, Human Body, Humanities, Leisure, Engineering, and Other. These categories provide a structured framework for all subjects across the platform.',
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
      'premium_upgrade_title': 'Upgrade to Premium',
      'premium_upgrade_desc': 'Unlock all features and math engines',
      'premium_manage': 'Manage',
      'premium_go': 'Go Premium',
      'premium_member': 'Premium Member',
      'manage_subscription': 'Manage Subscription',
      'session_complete_description': 'You have finished reviewing all cards in this session.',
      'source': 'Source',
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
    'id': {
      'documentation': 'Dokumentasi',
      'show_documentation_btn': 'Tampilkan Tombol Dokumentasi',
      'show_documentation_btn_desc': 'Menampilkan ikon bantuan di bilah navigasi atas',
      'support_and_management': 'Dukungan & Tentang',
      'about_tagline': 'Belajar Visual. Kuasai Selamanya.',
      'next_daily_goal_desc': 'Target jumlah kartu yang harus dikuasai setiap hari. Perubahan berlaku mulai besok.',
      'learn_session_size_desc': 'Jumlah kartu baru yang diperkenalkan dalam satu sesi belajar.',
      'test_session_size_desc': 'Jumlah kartu yang akan ditinjau dalam satu sesi pengujian.',
      'options_count_desc': 'Jumlah jawaban pilihan ganda yang ditampilkan selama tes.',
      'total_cards': 'Total Kartu',
      'correct_answers': 'Jawaban Benar',
      'failed_answers': 'Gagal',
      'premium_go': 'Jadi Premium',
      'manage_subscription': 'Kelola Langganan',
      'premium_member': 'Anggota Premium',
      'premium_active': 'Aliolo Premium Aktif',
      'premium_active_desc': 'Kelola langganan atau ubah paket Anda',
      'premium_upgrade_title': 'Tingkatkan ke Premium',
      'premium_upgrade_desc': 'Buka semua fitur dan mesin matematika',
      'premium_manage': 'Kelola',
      'dashboard_greeting': 'Halo',
      'session_complete_description': 'Anda telah selesai meninjau semua kartu dalam sesi ini.',
    },
    'bg': {
      'documentation': 'Документация',
      'show_documentation_btn': 'Показване на бутона за документация',
      'show_documentation_btn_desc': 'Показване на икона за помощ в горната лента за навигация',
      'support_and_management': 'Поддръжка и Информация',
      'about_tagline': 'Учете визуално. Овладейте завинаги.',
      'next_daily_goal_desc': 'Целеви брой карти за усвояване всеки ден. Промените влизат в сила от утре.',
      'learn_session_size_desc': 'Брой нови карти, които да бъдат въведени в една учебна сесия.',
      'test_session_size_desc': 'Брой карти за преглед в една сесия за тестване.',
      'options_count_desc': 'Брой отговори с избор от няколко възможности, показвани по време на тестовете.',
      'total_cards': 'Общо карти',
      'correct_answers': 'Правилни отговори',
      'failed_answers': 'Неуспешни',
      'premium_go': 'Стани Премиум',
      'manage_subscription': 'Управление на абонамента',
      'premium_member': 'Премиум член',
      'premium_active': 'Активен Aliolo Premium',
      'premium_active_desc': 'Управлявайте абонамента си или променете плановете',
      'premium_upgrade_title': 'Надграждане до Премиум',
      'premium_upgrade_desc': 'Отключете всички функции и математически двигатели',
      'premium_manage': 'Управление',
      'dashboard_greeting': 'Здравей',
      'session_complete_description': 'Завършихте прегледа на всички карти в тази сесия.',
    },
    'cs': {
      'documentation': 'Dokumentace',
      'show_documentation_btn': 'Zobrazit tlačítko dokumentace',
      'show_documentation_btn_desc': 'Zobrazit ikonu nápovědy v horní navigační liště',
      'support_and_management': 'Podpora a o aplikaci',
      'about_tagline': 'Učte se vizuálně. Ovládněte natrvalo.',
      'next_daily_goal_desc': 'Cílový počet karet k osvojení každý den. Změny vstoupí v platnost zítra.',
      'learn_session_size_desc': 'Počet nových karet k zavedení v jedné učební lekci.',
      'test_session_size_desc': 'Počet karet k přezkoumání v jedné testovací lekci.',
      'options_count_desc': 'Počet odpovědí s výběrem z více možností zobrazených během testů.',
      'total_cards': 'Celkem karet',
      'correct_answers': 'Správné odpovědi',
      'failed_answers': 'Neúspěšné',
      'premium_go': 'Získat Premium',
      'manage_subscription': 'Spravovat předplatné',
      'premium_member': 'Prémiový člen',
      'premium_active': 'Aliolo Premium aktivní',
      'premium_active_desc': 'Spravujte své předplatné nebo změňte plány',
      'premium_upgrade_title': 'Upgrade na Premium',
      'premium_upgrade_desc': 'Odemkněte všechny funkce a matematické moduly',
      'premium_manage': 'Spravovat',
      'dashboard_greeting': 'Ahoj',
      'session_complete_description': 'Dokončili jste kontrolu všech karet v této lekci.',
    },
    'da': {
      'documentation': 'Dokumentation',
      'show_documentation_btn': 'Vis dokumentationsknap',
      'show_documentation_btn_desc': 'Vis et hjælpeikon i den øverste navigationslinje',
      'support_and_management': 'Support og Om',
      'about_tagline': 'Lær visuelt. Mestrer for altid.',
      'next_daily_goal_desc': 'Målantal kort, der skal mestres hver dag. Ændringer træder i kraft i morgen.',
      'learn_session_size_desc': 'Antal nye kort, der skal introduceres i en enkelt læringssession.',
      'test_session_size_desc': 'Antal kort, der skal gennemgås i en enkelt testsession.',
      'options_count_desc': 'Antal svarmuligheder, der vises under test.',
      'total_cards': 'Antal kort i alt',
      'correct_answers': 'Korrekte svar',
      'failed_answers': 'Ikke bestået',
      'premium_go': 'Bliv Premium',
      'manage_subscription': 'Administrer abonnement',
      'premium_member': 'Premium-medlem',
      'premium_active': 'Aliolo Premium aktiv',
      'premium_active_desc': 'Administrer dit abonnement eller skift abonnement',
      'premium_upgrade_title': 'Opgrader til Premium',
      'premium_upgrade_desc': 'Lås op for alle funktioner og matematikmotorer',
      'premium_manage': 'Administrer',
      'dashboard_greeting': 'Hej',
      'session_complete_description': 'Du er færdig med at gennemse alle kort i denne session.',
    },
    'de': {
      'documentation': 'Dokumentation',
      'show_documentation_btn': 'Dokumentations-Schaltfläche anzeigen',
      'show_documentation_btn_desc': 'Ein Hilfe-Symbol in der oberen Navigationsleiste anzeigen',
      'support_and_management': 'Support & Über uns',
      'about_tagline': 'Visuell lernen. Dauerhaft beherrschen.',
      'next_daily_goal_desc': 'Zielanzahl der täglich zu beherrschenden Karten. Änderungen treten morgen in Kraft.',
      'learn_session_size_desc': 'Anzahl der neuen Karten, die in einer einzelnen Lernsitzung eingeführt werden.',
      'test_session_size_desc': 'Anzahl der Karten, die in einer einzelnen Testsitzung überprüft werden.',
      'options_count_desc': 'Anzahl der bei Tests angezeigten Multiple-Choice-Antworten.',
      'total_cards': 'Gesamtzahl der Karten',
      'correct_answers': 'Richtige Antworten',
      'failed_answers': 'Fehlgeschlagen',
      'premium_go': 'Premium werden',
      'manage_subscription': 'Abonnement verwalten',
      'premium_member': 'Premium-Mitglied',
      'premium_active': 'Aliolo Premium aktiv',
      'premium_active_desc': 'Abonnement verwalten oder Pläne ändern',
      'premium_upgrade_title': 'Auf Premium upgraden',
      'premium_upgrade_desc': 'Alle Funktionen und Mathe-Engines freischalten',
      'premium_manage': 'Verwalten',
      'dashboard_greeting': 'Hallo',
      'session_complete_description': 'Du hast alle Karten in dieser Sitzung abgeschlossen.',
    },
    'et': {
      'documentation': 'Dokumentatsioon',
      'show_documentation_btn': 'Näita dokumentatsiooni nuppu',
      'show_documentation_btn_desc': 'Kuva abiikoon ülemisel navigeerimisribal',
      'support_and_management': 'Tugi ja teave',
      'about_tagline': 'Õpi visuaalselt. Valda püsivalt.',
      'next_daily_goal_desc': 'Iga päiv omandatavate kaartide sihtarv. Muudatused jõustuvad homme.',
      'learn_session_size_desc': 'Ühes õppesessioonis tutvustatavate uute kaartide arv.',
      'test_session_size_desc': 'Ühes kontrollsessioonis ülevaadatavate kaartide arv.',
      'options_count_desc': 'Testide ajal kuvatavate valikvastuste arv.',
      'total_cards': 'Kaarte kokku',
      'correct_answers': 'Õiged vastused',
      'failed_answers': 'Ebaõnnestus',
      'premium_go': 'Mine Premiumile',
      'manage_subscription': 'Halda tellimust',
      'premium_member': 'Premium-liige',
      'premium_active': 'Aliolo Premium on aktiivne',
      'premium_active_desc': 'Halda oma tellimust või muuda pakette',
      'premium_upgrade_title': 'Uuenda Premiumiks',
      'premium_upgrade_desc': 'Ava kõik funktsioonid ja matemaatikamootorid',
      'premium_manage': 'Halda',
      'dashboard_greeting': 'Tere',
      'session_complete_description': 'Olete lõpetanud kõigi selle sessiooni kaartide läbivaatamise.',
    },
    'es': {
      'documentation': 'Documentación',
      'show_documentation_btn': 'Mostrar botón de documentación',
      'show_documentation_btn_desc': 'Mostrar un icono de ayuda en la barra de navegación superior',
      'support_and_management': 'Soporte y Acerca de',
      'about_tagline': 'Aprende visualmente. Domina para siempre.',
      'next_daily_goal_desc': 'Número objetivo de tarjetas a dominar cada día. Los cambios surten efecto mañana.',
      'learn_session_size_desc': 'Número de tarjetas nuevas a introducir en una sola sesión de aprendizaje.',
      'test_session_size_desc': 'Número de tarjetas a revisar en una sola sesión de prueba.',
      'options_count_desc': 'Número de respuestas de opción múltiple que se muestran durante las pruebas.',
      'total_cards': 'Total de tarjetas',
      'correct_answers': 'Respuestas correctas',
      'failed_answers': 'Fallidas',
      'premium_go': 'Hazte Premium',
      'manage_subscription': 'Gestionar suscripción',
      'premium_member': 'Miembro Premium',
      'premium_active': 'Aliolo Premium Activo',
      'premium_active_desc': 'Gestiona tu suscripción o cambia de plan',
      'premium_upgrade_title': 'Mejorar a Premium',
      'premium_upgrade_desc': 'Desbloquea todas las funciones y motores matemáticos',
      'premium_manage': 'Gestionar',
      'dashboard_greeting': 'Hola',
      'session_complete_description': 'Has terminado de revisar todas las tarjetas de esta sesión.',
    },
    'fr': {
      'documentation': 'Documentation',
      'show_documentation_btn': 'Afficher le bouton de documentation',
      'show_documentation_btn_desc': 'Afficher une icône d\'aide dans la barra de navigation supérieure',
      'support_and_management': 'Support et À propos',
      'about_tagline': 'Apprenez visuellement. Maîtrisez durablement.',
      'next_daily_goal_desc': 'Nombre cible de cartes à maîtriser chaque jour. Les modifications prendront effet demain.',
      'learn_session_size_desc': 'Nombre de nouvelles cartes à introduire dans une seule session d\'apprentissage.',
      'test_session_size_desc': 'Nombre de cartes à réviser dans une seule session de test.',
      'options_count_desc': 'Nombre de réponses à choix multiples affichées lors des tests.',
      'total_cards': 'Total de cartes',
      'correct_answers': 'Réponses correctes',
      'failed_answers': 'Échoué',
      'premium_go': 'Passer au Premium',
      'manage_subscription': 'Gérer l\'abonnement',
      'premium_member': 'Membre Premium',
      'premium_active': 'Aliolo Premium Actif',
      'premium_active_desc': 'Gérez votre abonnement ou changez de forfait',
      'premium_upgrade_title': 'Passer à Premium',
      'premium_upgrade_desc': 'Débloquez toutes les fonctionnalités et les moteurs de calcul',
      'premium_manage': 'Gérer',
      'dashboard_greeting': 'Bonjour',
      'session_complete_description': 'Vous avez fini de réviser toutes les cartes de cette session.',
    },
    'ga': {
      'documentation': 'Doiciméadúchán',
      'show_documentation_btn': 'Taispeáin Cnaipe Doiciméadúcháin',
      'show_documentation_btn_desc': 'Taispeáin deilbhín cabhrach sa bharra nascleanúna uachtarach',
      'support_and_management': 'Tacaíocht & Maidir le',
      'about_tagline': 'Foghlaim go hamhairc. Máistir go buan.',
      'next_daily_goal_desc': 'Sprioclíon cártaí le máistir gach lá. Tiocfaidh athruithe i bhfeidhm amárach.',
      'learn_session_size_desc': 'Líon na gcártaí nua le tabhairt isteach i seisiún foghlama amháin.',
      'test_session_size_desc': 'Líon na gcártaí le hathbhreithniú i seisiún tástála amháin.',
      'options_count_desc': 'Líon na bhfreagraí ilroghnacha a thaispeántar le linn tástálacha.',
      'total_cards': 'Iomlán na gCártaí',
      'correct_answers': 'Freagraí Cearta',
      'failed_answers': 'Teipthe',
      'premium_go': 'Téigh Premium',
      'manage_subscription': 'Bainistigh Suas-scríobh',
      'premium_member': 'Ball Préimhe',
      'premium_active': 'Aliolo Premium Gníomhach',
      'premium_active_desc': 'Bainistigh do shíntiús nó athraigh pleananna',
      'premium_upgrade_title': 'Uasghrádaigh go Premium',
      'premium_upgrade_desc': 'Díghlasáil gach gné agus inneall matamataice',
      'premium_manage': 'Bainistigh',
      'dashboard_greeting': 'Dia duit',
      'session_complete_description': 'Tá athbhreithniú déanta agat ar gach cárta sa seisiún seo.',
    },
    'hr': {
      'documentation': 'Dokumentacija',
      'show_documentation_btn': 'Prikaži gumb za dokumentaciju',
      'show_documentation_btn_desc': 'Prikaži ikону pomoći u gornjoj navigacijskoj traci',
      'support_and_management': 'Podrška i O aplikaciji',
      'about_tagline': 'Učite vizualno. Ovladajte trajno.',
      'next_daily_goal_desc': 'Ciljni broj kartica koje treba savladati svaki dan. Promjene stupaju na snagu sutra.',
      'learn_session_size_desc': 'Broj novih kartica koje se uvode u jednoj sesiji učenja.',
      'test_session_size_desc': 'Broj kartica koje treba pregledati u jednoj sesiji testiranja.',
      'options_count_desc': 'Broj odgovora s višestrukim izborom prikazanih tijekom testova.',
      'total_cards': 'Ukupno kartica',
      'correct_answers': 'Točni odgovori',
      'failed_answers': 'Neuspješno',
      'premium_go': 'Postani Premium',
      'manage_subscription': 'Upravljanje pretplatom',
      'premium_member': 'Premium član',
      'premium_active': 'Aliolo Premium aktivan',
      'premium_active_desc': 'Upravljajte svojom pretplatom ili promijenite planove',
      'premium_upgrade_title': 'Nadogradi na Premium',
      'premium_upgrade_desc': 'Otključajte sve značajke i matematičke module',
      'premium_manage': 'Upravljaj',
      'dashboard_greeting': 'Zdravo',
      'session_complete_description': 'Završili ste pregled svih kartica u ovoj sesiji.',
    },
    'it': {
      'documentation': 'Documentazione',
      'show_documentation_btn': 'Mostra pulsante documentazione',
      'show_documentation_btn_desc': 'Mostra un\'icona di aiuto nella barra di navigazione superiore',
      'support_and_management': 'Supporto e Informazioni',
      'about_tagline': 'Impara visivamente. Padroneggia per sempre.',
      'next_daily_goal_desc': 'Numero target di carte da padroneggiare ogni giorno. Le modifiche avranno effetto da domani.',
      'learn_session_size_desc': 'Numero di nuove carte da introdurre in una singola sessione di apprendimento.',
      'test_session_size_desc': 'Numero di carte da rivedere in una singola sessione di test.',
      'options_count_desc': 'Numero di risposte a scelta multipla visualizzate durante i test.',
      'total_cards': 'Totale carte',
      'correct_answers': 'Risposte corrette',
      'failed_answers': 'Fallite',
      'premium_go': 'Passa a Premium',
      'manage_subscription': 'Gestisci abbonamento',
      'premium_member': 'Membro Premium',
      'premium_active': 'Aliolo Premium Attivo',
      'premium_active_desc': 'Gestisci il tuo abbonamento o cambia piano',
      'premium_upgrade_title': 'Passa a Premium',
      'premium_upgrade_desc': 'Sblocca tutte le funzioni e i motori matematici',
      'premium_manage': 'Gestisci',
      'dashboard_greeting': 'Ciao',
      'session_complete_description': 'Hai finito di rivedere tutte le carte in questa sessione.',
    },
    'lv': {
      'documentation': 'Dokumentācija',
      'show_documentation_btn': 'Rādīt dokumentācijas pogu',
      'show_documentation_btn_desc': 'Rādīt palīdzības ikonu augšējā navigācijas joslā',
      'support_and_management': 'Atbalsts un Par',
      'about_tagline': 'Mācieties vizuāli. Apgūstiet uz visiem laikiem.',
      'next_daily_goal_desc': 'Katru dienu apgūstamo karšu mērķa skaits. Izmaiņas stājas spēkā rīt.',
      'learn_session_size_desc': 'Vienā mācību sesijā ieviešamo jauno karšu skaits.',
      'test_session_size_desc': 'Vienā testēšanas sesijā pārskatāmo karšu skaits.',
      'options_count_desc': 'Testu laikā parādīto atbilžu variantu skaits.',
      'total_cards': 'Kopā kartītes',
      'correct_answers': 'Pareizās atbildes',
      'failed_answers': 'Neizdevās',
      'premium_go': 'Kļūt par Premium',
      'manage_subscription': 'Pārvaldīt abonementu',
      'premium_member': 'Premium biedrs',
      'premium_active': 'Aliolo Premium aktīvs',
      'premium_active_desc': 'Pārvaldiet savu abonementu vai mainiet plānus',
      'premium_upgrade_title': 'Jaunināt uz Premium',
      'premium_upgrade_desc': 'Atbloķējiet visas funkcijas un matemātikas moduļus',
      'premium_manage': 'Pārvaldīt',
      'dashboard_greeting': 'Sveiki',
      'session_complete_description': 'Jūs esat pabeidzis visu šīs sesijas karšu pārskatīšanu.',
    },
    'lt': {
      'documentation': 'Dokumentacija',
      'show_documentation_btn': 'Rodyti dokumentacijos mygtuką',
      'show_documentation_btn_desc': 'Rodyti pagalbos piktogramą viršutinėje navigacijos juostoje',
      'support_and_management': 'Palaikymas ir Apie',
      'about_tagline': 'Mokykitės vizualiai. Įsisavinkite visam laikui.',
      'next_daily_goal_desc': 'Tikslinis kortelių skaičius, kurį reikia išmokti kiekvieną dieną. Pakeitimai įsigalios rytoj.',
      'learn_session_size_desc': 'Naujų kortelių skaičius, kurį reikia pristatyti vienoje mokymosi sesijoje.',
      'test_session_size_desc': 'Peržiūrimų kortelių skaičius vienoje testavimo sesijoje.',
      'options_count_desc': 'Testų metu rodomų pasirinkimo variantų skaičius.',
      'total_cards': 'Iš viso kortelių',
      'correct_answers': 'Teisingi atsakymai',
      'failed_answers': 'Nepavyko',
      'premium_go': 'Gauti Premium',
      'manage_subscription': 'Valdyti prenumeratą',
      'premium_member': 'Premium narys',
      'premium_active': '„Aliolo Premium“ aktyvus',
      'premium_active_desc': 'Valdykite prenumeratą arba keiskite planus',
      'premium_upgrade_title': 'Atnaujinti į „Premium“',
      'premium_upgrade_desc': 'Atrakinkite visas funkcijas ir matematikos variklius',
      'premium_manage': 'Valdyti',
      'dashboard_greeting': 'Labas',
      'session_complete_description': 'Baigėte peržiūrėti visas šios sesijos korteles.',
    },
    'hu': {
      'documentation': 'Dokumentáció',
      'show_documentation_btn': 'Dokumentáció gomb megjelenítése',
      'show_documentation_btn_desc': 'Súgó ikon megjelenítése a felső navigációs sávban',
      'support_and_management': 'Támogatás és Névjegy',
      'about_tagline': 'Tanulj vizuálisan. Sajátítsd el örökre.',
      'next_daily_goal_desc': 'A naponta elsajátítandó kártyák célszáma. A módosítások holnap lépnek életbe.',
      'learn_session_size_desc': 'Egyetlen tanulási szakaszban bevezetendő új kártyák száma.',
      'test_session_size_desc': 'Egyetlen tesztelési szakaszban áttekintendő kártyák száma.',
      'options_count_desc': 'A tesztek során megjelenített feleletválasztós válaszok száма.',
      'total_cards': 'Összes kártya',
      'correct_answers': 'Helyes válaszok',
      'failed_answers': 'Sikertelen',
      'premium_go': 'Váltás Prémiumra',
      'manage_subscription': 'Előfizetés kezelése',
      'premium_member': 'Prémium tag',
      'premium_active': 'Aliolo Prémium Aktív',
      'premium_active_desc': 'Kezelje előfizetését vagy változtasson csomagot',
      'premium_upgrade_title': 'Frissítés Prémiumra',
      'premium_upgrade_desc': 'Oldja fel az összes funkciót és matematikai modult',
      'premium_manage': 'Kezelés',
      'dashboard_greeting': 'Szia',
      'session_complete_description': 'Befejezte a szakasz összes kártyájának áttekintését.',
    },
    'mt': {
      'documentation': 'Dokumentazzjoni',
      'show_documentation_btn': 'Uri l-buttuna tad-dokumentazzjoni',
      'show_documentation_btn_desc': 'Uri ikona tal-għajnuna fil-bar tan-navigazzjoni ta\' fuq',
      'support_and_management': 'Appoġġ u Dwar',
      'about_tagline': 'Tgħallem viżwalment. Ikkontrolla għal dejjem.',
      'next_daily_goal_desc': 'Numru fil-mira ta\' kards li għandhom jiġu mhaddma kull jum. Il-bidliet jidħlu fis-seħħ għada.',
      'learn_session_size_desc': 'Numru ta\' kards ġodda li għandhom jiġu introdotti f\'sessjoni ta\' tagħlim waħda.',
      'test_session_size_desc': 'Numru ta\' kards li għandhom jiġu riveduti f\'sessjoni ta\' ttestjar waħda.',
      'options_count_desc': 'Numru ta\' tweġibiet b\'għażla multipla murija waqt it-testijiet.',
      'total_cards': 'Total ta\' Karti',
      'correct_answers': 'Tweġibiet Korretti',
      'failed_answers': 'Fallew',
      'premium_go': 'Mur Premium',
      'manage_subscription': 'Immaniġġja l-abbonament',
      'premium_member': 'Membru Premium',
      'premium_active': 'Aliolo Premium Attiv',
      'premium_active_desc': 'Immaniġġja l-abbonament tiegħek jew ibdel il-pjanijiet',
      'premium_upgrade_title': 'Aġġorna għal Premium',
      'premium_upgrade_desc': 'Iftaħ il-karatteristiċi kollha u l-magni tal-matematika',
      'premium_manage': 'Immaniġġja',
      'dashboard_greeting': 'Bongu',
      'session_complete_description': 'Lestiet ir-reviżjoni tal-kards kollha f\'din is-sessjoni.',
    },
    'nl': {
      'documentation': 'Documentatie',
      'show_documentation_btn': 'Documentatieknop weergeven',
      'show_documentation_btn_desc': 'Help-icoon weergeven in de bovenste navigatiebalk',
      'support_and_management': 'Ondersteuning & Over',
      'about_tagline': 'Leer visueel. Beheers blijvend.',
      'next_daily_goal_desc': 'Doelaantal kaarten om elke dag onder de knie te krijgen. Wijzigingen gaan morgen in.',
      'learn_session_size_desc': 'Aantal nieuwe kaarten dat in één leersessie wordt geïntroduceerd.',
      'test_session_size_desc': 'Aantal kaarten dat in één testsessie wordt beoordeeld.',
      'options_count_desc': 'Aantal meerkeuze-antwoorden dat tijdens tests wordt weergegeven.',
      'total_cards': 'Totaal aantal kaarten',
      'correct_answers': 'Correcte antwoorden',
      'failed_answers': 'Mislukt',
      'premium_go': 'Ga naar Premium',
      'manage_subscription': 'Abonnement beheren',
      'premium_member': 'Premium lid',
      'premium_active': 'Aliolo Premium Actief',
      'premium_active_desc': 'Beheer uw abonnement of wijzig plannen',
      'premium_upgrade_title': 'Upgraden naar Premium',
      'premium_upgrade_desc': 'Ontgrendel alle functies en wiskundemotoren',
      'premium_manage': 'Beheren',
      'dashboard_greeting': 'Hallo',
      'session_complete_description': 'Je hebt alle kaarten in deze sessie bekeken.',
    },
    'pl': {
      'documentation': 'Dokumentacja',
      'show_documentation_btn': 'Pokaż przycisk dokumentacji',
      'show_documentation_btn_desc': 'Wyświetl ikonę pomocy w górnym pasku nawigacyjnym',
      'support_and_management': 'Wsparcie i informacje',
      'about_tagline': 'Ucz się wizualnie. Opanuj na zawsze.',
      'next_daily_goal_desc': 'Docelowa liczba kart do opanowania każdego dnia. Zmiany wejdą w życie jutro.',
      'learn_session_size_desc': 'Liczba nowych kart do wprowadzenia in unei sesji nauki.',
      'test_session_size_desc': 'Liczba kart do powtórzenia w jednej sesji testowej.',
      'options_count_desc': 'Liczba odpowiedzi wielokrotnego wyboru wyświetlanych podczas testów.',
      'total_cards': 'Wszystkie karty',
      'correct_answers': 'Poprawne odpowiedzi',
      'failed_answers': 'Nieudane',
      'premium_go': 'Przejdź na Premium',
      'manage_subscription': 'Zarządzaj subskrypcją',
      'premium_member': 'Członek Premium',
      'premium_active': 'Aliolo Premium Aktywny',
      'premium_active_desc': 'Zarządzaj subskrypcją lub zmień plany',
      'premium_upgrade_title': 'Uaktualnij do Premium',
      'premium_upgrade_desc': 'Odblokuj wszystkie funkcje i silniki matematyczne',
      'premium_manage': 'Zarządzaj',
      'dashboard_greeting': 'Cześć',
      'session_complete_description': 'Zakończyłeś przeglądanie wszystkich kart w tej sesji.',
    },
    'pt': {
      'documentation': 'Documentação',
      'show_documentation_btn': 'Mostrar botón de documentación',
      'show_documentation_btn_desc': 'Exibir um ícone de ayuda en la barra de navigação superior',
      'support_and_management': 'Suporte e Sobre',
      'about_tagline': 'Aprenda visualmente. Domine para siempre.',
      'next_daily_goal_desc': 'Número alvo de cartões para dominar todos os dos dias. As alterações entram em vigor amãnhã.',
      'learn_session_size_desc': 'Número de novos cartões a introduzir numa única sessão de aprendizagem.',
      'test_session_size_desc': 'Número de cartões a rever numa única sessão de test.',
      'options_count_desc': 'Número de respostas de escolha múltipla apresentadas durante os testes.',
      'total_cards': 'Total de cartões',
      'correct_answers': 'Respostas correctas',
      'failed_answers': 'Falhadas',
      'premium_go': 'Torne-se Premium',
      'manage_subscription': 'Gerenciar assinatura',
      'premium_member': 'Membro Premium',
      'premium_active': 'Aliolo Premium Ativo',
      'premium_active_desc': 'Gerencie sua assinatura ou altere planos',
      'premium_upgrade_title': 'Atualizar para Premium',
      'premium_upgrade_desc': 'Desbloqueie todos os recursos e motores matemáticos',
      'premium_manage': 'Gerenciar',
      'dashboard_greeting': 'Olá',
      'session_complete_description': 'Terminou de rever todos os cartões nesta sessão.',
    },
    'ro': {
      'documentation': 'Documentație',
      'show_documentation_btn': 'Afișεază butonul de documentație',
      'show_documentation_btn_desc': 'Afișează o pictogramă de ajutor în bara de navigare superioară',
      'support_and_management': 'Suport și Despre',
      'about_tagline': 'Învață vizual. Stăpânește permanent.',
      'next_daily_goal_desc': 'Numărul țintă de carduri de stăpânit în fiecare zi. Modificările intră în vigoare mâine.',
      'learn_session_size_desc': 'Numărul de carduri noi de introdus într-o singură sesiune de învățare.',
      'test_session_size_desc': 'Numărul de carduri de revizuit într-o singură sesiune de testare.',
      'options_count_desc': 'Numărul de răspunsuri cu alegere multiplă afișate în timpul testelor.',
      'total_cards': 'Total carduri',
      'correct_answers': 'Răspunsuri corecte',
      'failed_answers': 'Eșuate',
      'premium_go': 'Treci la Premium',
      'manage_subscription': 'Gestionează abonamentul',
      'premium_member': 'Membru Premium',
      'premium_active': 'Aliolo Premium Activ',
      'premium_active_desc': 'Gestionează-ți abonamentul sau schimbă planurile',
      'premium_upgrade_title': 'Treci la Premium',
      'premium_upgrade_desc': 'Deblochează toate funcțiile și motoarele matematice',
      'premium_manage': 'Gestionează',
      'dashboard_greeting': 'Bună',
      'session_complete_description': 'Ați terminat de revizuit toate cardurile din această sesiune.',
    },
    'sk': {
      'documentation': 'Dokumentácia',
      'show_documentation_btn': 'Zobraziť tlačidlo dokumentácie',
      'show_documentation_btn_desc': 'Zobraziť ikonu pomocníka v hornej navigačnej lište',
      'support_and_management': 'Podpora a o aplikácii',
      'about_tagline': 'Učte sa vizuálne. Ovládnite navždy.',
      'next_daily_goal_desc': 'Cieľový počet kariet, ktoré si treba každý deň osvojiť. Zmeny nadobudnú účinnosť zajtra.',
      'learn_session_size_desc': 'Počet nových kariet, ktoré sa majú zaviesť v jednej lekcii učenia.',
      'test_session_size_desc': 'Počet kariet, ktoré sa majú skontrolovať v jednej testovacej lekcii.',
      'options_count_desc': 'Počet odpovedí s výberom z viacerých možností zobrazených počas testov.',
      'total_cards': 'Celkom kariet',
      'correct_answers': 'Správne odpovede',
      'failed_answers': 'Neúspešné',
      'premium_go': 'Prejsť na Premium',
      'manage_subscription': 'Spravovať predplatné',
      'premium_member': 'Prémiový člen',
      'premium_active': 'Aliolo Premium aktívne',
      'premium_active_desc': 'Spravujte svoje predplatné alebo zmeňte plány',
      'premium_upgrade_title': 'Upgrade na Premium',
      'premium_upgrade_desc': 'Odomknite všetky funkcie a matematické moduly',
      'premium_manage': 'Spravovať',
      'dashboard_greeting': 'Ahoj',
      'session_complete_description': 'Dokončili ste kontrolu všetkých kariet v tejto relácii.',
    },
    'sl': {
      'documentation': 'Dokumentacija',
      'show_documentation_btn': 'Prikaži gumb za dokumentacijo',
      'show_documentation_btn_desc': 'Prikaži ikonu pomoči v zgornji navigacijski vrstici',
      'support_and_management': 'Podpora in O aplikaciji',
      'about_tagline': 'Učite se vizualno. Obvladajte trajno.',
      'next_daily_goal_desc': 'Ciljno število kartic, ki jih je treba osvojiti vsak dan. Spremembe začnejo veljati jutri.',
      'learn_session_size_desc': 'Število novih kartic, ki se uvedejo v eni učni seji.',
      'test_session_size_desc': 'Število kartic za pregled v eni testni seji.',
      'options_count_desc': 'Število odgovorov z več izbirami, prikazanih med testi.',
      'total_cards': 'Skupaj kartic',
      'correct_answers': 'Pravilni odgovori',
      'failed_answers': 'Neuspešno',
      'premium_go': 'Postani Premium',
      'manage_subscription': 'Upravljanje naročnine',
      'premium_member': 'Premium član',
      'premium_active': 'Aliolo Premium aktiven',
      'premium_active_desc': 'Upravljajte svojo naročnino ali spremenite načrte',
      'premium_upgrade_title': 'Nadgradi na Premium',
      'premium_upgrade_desc': 'Odklenite vse funkcije in matematične mehanizme',
      'premium_manage': 'Upravljanje',
      'dashboard_greeting': 'Živjo',
      'session_complete_description': 'Pregledali ste vse kartice v tej seji.',
    },
    'fi': {
      'documentation': 'Dokumentaatio',
      'show_documentation_btn': 'Näytä dokumentaatiopainike',
      'show_documentation_btn_desc': 'Näytä ohjekuvake yläreunan navigointipalkissa',
      'support_and_management': 'Tuki ja Tietoja',
      'about_tagline': 'Opi visuaalisesti. Hallitse pysyvästi.',
      'next_daily_goal_desc': 'Päivittäinen tavoitemäärä hallittavia kortteja. Muutokset astuvat voimaan huomenna.',
      'learn_session_size_desc': 'Yhdessä oppimisistunnossa esiteltävien uusien korttien määrä.',
      'test_session_size_desc': 'Yhdessä testausistunnossa kerrattavien korttien määrä.',
      'options_count_desc': 'Testeissä näytettävien monivalintavastausten määrä.',
      'total_cards': 'Kortteja yhteensä',
      'correct_answers': 'Oikeat vastaukset',
      'failed_answers': 'Epäonnistui',
      'premium_go': 'Hanki Premium',
      'manage_subscription': 'Hallitse tilausta',
      'premium_member': 'Premium-jäsen',
      'premium_active': 'Aliolo Premium aktiivinen',
      'premium_active_desc': 'Hallitse tilaustasi tai vaihda sopimusta',
      'premium_upgrade_title': 'Päivitä Premiumiin',
      'premium_upgrade_desc': 'Avaa kaikki toiminnot ja matematiikkamoottorit',
      'premium_manage': 'Hallitse',
      'dashboard_greeting': 'Hei',
      'session_complete_description': 'Olet käynyt läpi kaikki tämän istunnon kortit.',
    },
    'sv': {
      'documentation': 'Dokumentation',
      'show_documentation_btn': 'Visa dokumentationsknapp',
      'show_documentation_btn_desc': 'Visa en hjälpikon i det övre navigeringsfältet',
      'support_and_management': 'Support och Om',
      'about_tagline': 'Lär dig visuellt. Bemästra för alltid.',
      'next_daily_goal_desc': 'Målantal kort att bemästra varje dag. Ändringar träder i kraft i morgon.',
      'learn_session_size_desc': 'Antal nya kort som ska introduceras i en enda inlärningssession.',
      'test_session_size_desc': 'Antal kort som ska repeteras i en enda testsession.',
      'options_count_desc': 'Antal flervalsalternativ som visas under test.',
      'total_cards': 'Totalt antal kort',
      'correct_answers': 'Rätt svar',
      'failed_answers': 'Misslyckades',
      'premium_go': 'Skaffa Premium',
      'manage_subscription': 'Hantera prenumeration',
      'premium_member': 'Premium-medlem',
      'premium_active': 'Aliolo Premium aktiv',
      'premium_active_desc': 'Hantera din prenumeration eller byt abonnemang',
      'premium_upgrade_title': 'Uppgradera till Premium',
      'premium_upgrade_desc': 'Lås upp alla funktioner och matematikmotorer',
      'premium_manage': 'Hantera',
      'dashboard_greeting': 'Hej',
      'session_complete_description': 'Du har granskat klart alla kort i den här sessionen.',
    },
    'tl': {
      'documentation': 'Dokumentasyon',
      'show_documentation_btn': 'Ipakita ang Button ng Dokumentasyon',
      'show_documentation_btn_desc': 'Ipakita ang icon ng tulong sa itaas na navigation bar',
      'support_and_management': 'Suporta at Tungkol',
      'about_tagline': 'Matuto nang Visual. Kabisaduhin nang Lubusan.',
      'next_daily_goal_desc': 'Target na bilang ng mga card na dapat makabisado bawat araw. Magkakabisa ang mga pagbabago bukas.',
      'learn_session_size_desc': 'Bilang ng mga bagong card na ipakikilala sa isang learning session.',
      'test_session_size_desc': 'Bilang ng mga card na susuriin sa isang testing session.',
      'options_count_desc': 'Bilang ng mga multiple-choice na sagot na ipinapakita sa panahon ng mga pagsusulit.',
      'total_cards': 'Kabuuang mga Kard',
      'correct_answers': 'Tamang mga Sagot',
      'failed_answers': 'Nabigo',
      'premium_go': 'Mag-Premium',
      'manage_subscription': 'Pamahalaan ang Subscription',
      'premium_member': 'Miyembrong Premium',
      'premium_active': 'Aktibo ang Aliolo Premium',
      'premium_active_desc': 'Pamahalaan ang iyong subscription o magpalit ng mga plan',
      'premium_upgrade_title': 'Mag-upgrade sa Premium',
      'premium_upgrade_desc': 'I-unlock ang lahat ng feature at math engine',
      'premium_manage': 'Pamahalaan',
      'dashboard_greeting': 'Halo',
      'session_complete_description': 'Natapos mo nang suriin ang lahat ng mga card sa session na ito.',
    },
    'vi': {
      'documentation': 'Tài liệu',
      'show_documentation_btn': 'Hiển thị nút tài liệu',
      'show_documentation_btn_desc': 'Hiển thị biểu tượng trợ giúp trong thanh điều hướng trên cùng',
      'support_and_management': 'Hỗ trợ & Giới thiệu',
      'about_tagline': 'Học bằng hình ảnh. Làm chủ mãi mãi.',
      'next_daily_goal_desc': 'Số lượng thẻ mục tiêu cần nắm vững mỗi ngày. Thay đổi có hiệu lực từ ngày mai.',
      'learn_session_size_desc': 'Số lượng thẻ mới cần giới thiệu trong một phiên học.',
      'test_session_size_desc': 'Số lượng thẻ cần ôn tập trong một phiên kiểm tra.',
      'options_count_desc': 'Số lượng câu trả lời trắc nghiệm được hiển thị trong các bài kiểm tra.',
      'total_cards': 'Tổng số thẻ',
      'correct_answers': 'Câu trả lời đúng',
      'failed_answers': 'Thất bại',
      'premium_go': 'Lên Premium',
      'manage_subscription': 'Quản lý đăng ký',
      'premium_member': 'Thành viên Premium',
      'premium_active': 'Aliolo Premium Đang hoạt động',
      'premium_active_desc': 'Quản lý đăng ký của bạn hoặc thay đổi gói',
      'premium_upgrade_title': 'Nâng cấp lên Premium',
      'premium_upgrade_desc': 'Mở khóa tất cả các tính năng και công cụ toán học',
      'premium_manage': 'Quản lý',
      'dashboard_greeting': 'Xin chào',
      'session_complete_description': 'Bạn đã hoàn thành việc ôn tập tất cả các thẻ trong phiên này.',
    },
    'tr': {
      'documentation': 'Dokümantasyon',
      'show_documentation_btn': 'Dokümantasyon Butonunu Göster',
      'show_documentation_btn_desc': 'Üst navigasyon çubuğunda bir yardım simgesi görüntüle',
      'support_and_management': 'Destek ve Hakkında',
      'about_tagline': 'Görselle Öğren. Kalıcı Olarak Ustalaş.',
      'next_daily_goal_desc': 'Her gün ustalaşılacak hedef card sayısı. Değişiklikler yarın yürürlüğe girecek.',
      'learn_session_size_desc': 'Tek bir öğrenme oturumunda tanıtılacak yeni card sayısı.',
      'test_session_size_desc': 'Tek bir test oturumunda gözden geçirilecek card sayısı.',
      'options_count_desc': 'Testler sırasında görüntülenen çoktan seçmeli cevap sayısı.',
      'total_cards': 'Toplam cardlar',
      'correct_answers': 'Doğru cevaplar',
      'failed_answers': 'Başarısız',
      'premium_go': 'Premium\'a Geç',
      'manage_subscription': 'Aboneliği Yönet',
      'premium_member': 'Premium Üye',
      'premium_active': 'Aliolo Premium Aktif',
      'premium_active_desc': 'Aboneliğinizi yönetin veya planları değiştirin',
      'premium_upgrade_title': 'Premium\'a Yükselt',
      'premium_upgrade_desc': 'Tüm özellikleri ve matematik motorlarını açın',
      'premium_manage': 'Yönet',
      'dashboard_greeting': 'Merhaba',
      'session_complete_description': 'Bu oturumdaki tüm kartları incelemeyi bitirdiniz.',
    },
    'el': {
      'documentation': 'Τεκμηρίωση',
      'show_documentation_btn': 'Εμφάνιση κουμπιού τεκμηρίωσης',
      'show_documentation_btn_desc': 'Εμφάνιση εικονιδίου βοήθειας στην επάνω γραμμή πλοήγησης',
      'support_and_management': 'Υποστήριξη & Σχετικά',
      'about_tagline': 'Μάθετε οπτικά. Κατακτήστε μόνιμα.',
      'next_daily_goal_desc': 'Στόχος αριθμού καρτών προς εκμάθηση κάθε μέρα. Οι αλλαγές τίθενται σε ισχύ από αύριο.',
      'learn_session_size_desc': 'Αριθμός νέων καρτών προς εισαγωγή σε μία μόνο συνεδρία εκμάθησης.',
      'test_session_size_desc': 'Αριθμός καρτών προς ανασκόπηση σε μία μόνο συνεδρία δοκιμής.',
      'options_count_desc': 'Αριθμός απαντήσεων πολλαπλής επιλογής που εμφανίζονται κατά τη διάρκεια των τεστ.',
      'total_cards': 'Σύνολο καρτών',
      'correct_answers': 'Σωστές απαντήσεις',
      'failed_answers': 'Αποτυχία',
      'premium_go': 'Γίνετε Premium',
      'manage_subscription': 'Διαχείριση συνδρομής',
      'premium_member': 'Μέλος Premium',
      'premium_active': 'Ενεργό Aliolo Premium',
      'premium_active_desc': 'Διαχειριστείτε τη συνδρομή σας ή αλλάξτε προγράμματα',
      'premium_upgrade_title': 'Αναβάθμιση σε Premium',
      'premium_upgrade_desc': 'Ξεκλειδώστε όλες τις λειτουργίες και τις μαθηματικές μηχανές',
      'premium_manage': 'Διαχείριση',
      'dashboard_greeting': 'Γεια σας',
      'session_complete_description': 'Ολοκληρώσατε την ανασκόπηση όλων των καρτών σε αυτήν τη συνεδρία.',
    },
    'uk': {
      'documentation': 'Документація',
      'show_documentation_btn': 'Показати кнопку документації',
      'show_documentation_btn_desc': 'Відображати іконку допомоги у верхній навігаційній панелі',
      'support_and_management': 'Підтримка та Про програму',
      'about_tagline': 'Навчайся візуально. Опановуй назавжди.',
      'next_daily_goal_desc': 'Цільова кількість карток для освоєння щодня. Зміни набудуть чинності завтра.',
      'learn_session_size_desc': 'Кількість нових карток для введення в одному навчальному занятті.',
      'test_session_size_desc': 'Кількість карток для перевірки в одному тестовому занятті.',
      'options_count_desc': 'Кількість варіантів відповіді, що відображаються під час тестів.',
      'total_cards': 'Всього карток',
      'correct_answers': 'Правильні відповіді',
      'failed_answers': 'Неправильні',
      'premium_go': 'Стати Premium',
      'manage_subscription': 'Керувати підпискою',
      'premium_member': 'Преміум-учасник',
      'premium_active': 'Aliolo Premium активований',
      'premium_active_desc': 'Керуйте підпискою або змінюйте плани',
      'premium_upgrade_title': 'Оновити до Premium',
      'premium_upgrade_desc': 'Розблокуйте всі функції та математичні двигуни',
      'premium_manage': 'Керувати',
      'dashboard_greeting': 'Привіт',
      'session_complete_description': 'Ви закінчили перегляд усіх карток у цій сесії.',
    },
    'ar': {
      'documentation': 'التوثيق',
      'show_documentation_btn': 'عرض زر التوثيق',
      'show_documentation_btn_desc': 'عرض أيقونة المساعدة في شريط التنقل العلوي',
      'support_and_management': 'الدعم وعن التطبيق',
      'about_tagline': 'تعلم بصرياً. أتقن للأبد.',
      'next_daily_goal_desc': 'عدد البطاقات المستهدف إتقانها كل يوم. تدخل التغييرات حيز التنفيذ غداً.',
      'learn_session_size_desc': 'عدد البطاقات الجديدة التي سيتم تقديمها في جلسة تعلم واحدة.',
      'test_session_size_desc': 'عدد البطاقات التي سيتم مراجعتها في جلسة اختبار واحدة.',
      'options_count_desc': 'عدد إجابات الاختيار من متعدد المعروضة أثناء الاختبارات.',
      'total_cards': 'إجمالي البطاقات',
      'correct_answers': 'إجابات صحيحة',
      'failed_answers': 'فشل',
      'premium_go': 'اشترك في بريميوم',
      'manage_subscription': 'إدارة الاشتراك',
      'premium_member': 'عضو بريميوم',
      'premium_active': 'Aliolo Premium نشط',
      'premium_active_desc': 'إدارة اشتراكك أو تغيير الخطط',
      'premium_upgrade_title': 'الترقية إلى بريميوم',
      'premium_upgrade_desc': 'فتح جميع الميزات والمحركات الرياضية',
      'premium_manage': 'إدارة',
      'dashboard_greeting': 'مرحبا',
      'session_complete_description': 'لقد انتهيت من مراجعة جميع البطاقات في هذه الجلسة.',
    },
    'hi': {
      'documentation': 'दस्तावेज़ीकरण',
      'show_documentation_btn': 'दस्तावेज़ीकरण बटन दिखाएं',
      'show_documentation_btn_desc': 'शीर्ष नेвиगेशन बार में सहायता आइकन प्रदर्शित करें',
      'support_and_management': 'सहायता और जानकारी',
      'about_tagline': 'विज़ुally सीखें। स्थायी महारत पाएं।',
      'next_daily_goal_desc': 'प्रत्येक दिन महारत हासिल करने के लिए कार्डों की लक्षิต संख्या। परिवर्तन कल से प्रभावी होंगे।',
      'learn_session_size_desc': 'एकल शिक्षण सत्र में पेश किए जाने वाले नए कार्डों की संख्या।',
      'test_session_size_desc': 'एकल परीक्षण सत्र में समीक्षा किए जाने वाले कार्डों की संख्या।',
      'options_count_desc': 'परीक्षणों के दौरान प्रदर्शित बहुविकल्पीय उत्तरों की संख्या।',
      'total_cards': 'कुल कार्ड',
      'correct_answers': 'सही उत्तर',
      'failed_answers': 'विफल',
      'premium_go': 'प्रीमियम प्राप्त करें',
      'manage_subscription': 'सदस्यता प्रबंधित करें',
      'premium_member': 'प्रीमियम सदस्य',
      'premium_active': 'Aliolo प्रीमियम सक्रिय',
      'premium_active_desc': 'अपनी सदस्यता प्रबंधित करें या योजनाएं बदलें',
      'premium_upgrade_title': 'प्रीमियम में अपग्रेड करें',
      'premium_upgrade_desc': 'सभी सुविधाओं और गणित इंजनों को अनलॉक करें',
      'premium_manage': 'प्रबंधित करें',
      'dashboard_greeting': 'नमस्ते',
      'session_complete_description': 'आपने इस सत्र के सभी कार्डों की समीक्षा पूरी कर ली है।',
    },
    'zh': {
      'documentation': '文档',
      'show_documentation_btn': '显示文档按钮',
      'show_documentation_btn_desc': '在顶部导航栏显示帮助图标',
      'support_and_management': '支持与关于',
      'about_tagline': '视觉学习，终身掌握。',
      'next_daily_goal_desc': '每日计划掌握的卡片目标数量. 更改将于明天生效。',
      'learn_session_size_desc': '单个学习环节中引入的新卡片数量。',
      'test_session_size_desc': '单个测试环节中复习的卡片数量。',
      'options_count_desc': '测试期间显示的多选题答案数量。',
      'total_cards': '卡片总数',
      'correct_answers': '正确答案',
      'failed_answers': '错误',
      'premium_go': '升级到高级版',
      'manage_subscription': '管理订阅',
      'premium_member': '高级会员',
      'premium_active': 'Aliolo 高级版已激活',
      'premium_active_desc': '管理您的订阅或更改方案',
      'premium_upgrade_title': '升级到高级版',
      'premium_upgrade_desc': '解锁所有功能和数学引擎',
      'premium_manage': '管理',
      'dashboard_greeting': '你好',
      'session_complete_description': '您已完成本环节中所有卡片的复习。',
    },
    'ja': {
      'documentation': 'ドキュメント',
      'show_documentation_btn': 'ドキュメントボタンを表示',
      'show_documentation_btn_desc': '上部のナビゲーションバーにヘルプアイコンを表示',
      'support_and_management': 'サポートと詳細',
      'about_tagline': '視覚で学び、一生モノの知識に.',
      'next_daily_goal_desc': '毎日マスターするカードの目標枚数。変更は明日から適用されます。',
      'learn_session_size_desc': '1回の学習セッションで導入する新しいカードの枚数。',
      'test_session_size_desc': '1回のテストセッションで復習するカードの枚数。',
      'options_count_desc': 'テスト中に表示される選択肢の数。',
      'total_cards': 'カード合計',
      'correct_answers': '正解',
      'failed_answers': '不正解',
      'premium_go': 'プレミアムにアップグレード',
      'manage_subscription': 'サブスクリプションの管理',
      'premium_member': 'プレミアム会員',
      'premium_active': 'Aliolo プレミアム有効',
      'premium_active_desc': 'サブスクリプションの管理またはプランの変更',
      'premium_upgrade_title': 'プレミアムにアップグレード',
      'premium_upgrade_desc': 'すべての機能と数学エンジンをアンロック',
      'premium_manage': '管理',
      'dashboard_greeting': 'こんにちは',
      'session_complete_description': 'このセッションのすべてのカードの学習が完了しました。',
    },
    'ko': {
      'documentation': '문서',
      'show_documentation_btn': '문서 버튼 표시',
      'show_documentation_btn_desc': '상단 내비게이션 바에 도움말 아이콘 표시',
      'support_and_management': '지원 및 정보',
      'about_tagline': '시각적으로 배우고 영원히 마스터하세요.',
      'next_daily_goal_desc': '매일 마스터할 카드 목표 수입니다. 변경 사항은 내일부터 적용됩니다.',
      'learn_session_size_desc': '단일 학습 세션에서 도입할 새 카드의 수입니다.',
      'test_session_size_desc': '단일 테스트 세션에서 검то할 카드의 수입니다.',
      'options_count_desc': '테스트 중 표시되는 객관식 답변 수입니다.',
      'total_cards': '총 카드 수',
      'correct_answers': '정답',
      'failed_answers': '실패',
      'premium_go': '프리미엄 가입하기',
      'manage_subscription': '구독 관리',
      'premium_member': '프리미엄 회원',
      'premium_active': 'Aliolo 프리미엄 활성',
      'premium_active_desc': '구독 관리 또는 요금제 변경',
      'premium_upgrade_title': '프리미엄으로 업그레이드',
      'premium_upgrade_desc': '모든 기능 및 수학 엔진 잠금 해제',
      'premium_manage': '관리',
      'dashboard_greeting': '안녕하세요',
      'session_complete_description': '이 세션의 모든 카드를 검토하셨습니다.',
    },
  };

  // Hardcoded fallback list - Sorted by Native Name (English first)
  static const List<String> _fallbackUILanguages = [
    'en',
    'id',
    'bg',
    'cs',
    'da',
    'de',
    'et',
    'es',
    'fr',
    'ga',
    'hr',
    'it',
    'lv',
    'lt',
    'hu',
    'mt',
    'nl',
    'pl',
    'pt',
    'ro',
    'sk',
    'sl',
    'fi',
    'sv',
    'tl',
    'vi',
    'tr',
    'el',
    'uk',
    'ar',
    'hi',
    'zh',
    'ja',
    'ko',
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
      final List<dynamic> data = await _supabase.from('languages').select('id, name').order('name');

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
      final List<dynamic> data =
          await _supabase.from('ui_translations').select('key, value').eq('lang', langCode);

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
      case 'zh':
        return '中文';
      case 'ja':
        return '日本語';
      case 'ko':
        return '한국어';
      case 'bg':
        return 'Български';
      case 'hr':
        return 'Hrvatski';
      case 'cs':
        return 'Čeština';
      case 'da':
        return 'Dansk';
      case 'et':
        return 'Eesti';
      case 'fi':
        return 'Suomi';
      case 'hu':
        return 'Magyar';
      case 'ga':
        return 'Gaeilge';
      case 'lv':
        return 'Latviešu';
      case 'lt':
        return 'Lietuvių';
      case 'mt':
        return 'Malti';
      case 'ro':
        return 'Română';
      case 'sk':
        return 'Slovenčina';
      case 'sl':
        return 'Slovenščina';
      case 'sv':
        return 'Svenska';
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
