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
      'about_tagline': 'Learn Visually. Master Permanently.',
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
      'next_daily_goal_desc': 'Target number of cards to master each day. Changes take effect tomorrow.',
      'learn_session_size_desc': 'Number of new cards to introduce in a single learning session.',
      'test_session_size_desc': 'Number of cards to review in a single testing session.',
      'options_count_desc': 'Number of multiple-choice answers displayed during tests.',
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
    },
    'cs': {
      'documentation': 'Dokumentace',
      'show_documentation_btn': 'Zobrazit tlačítko dokumentace',
      'show_documentation_btn_desc': 'Zobrazit ikonu nápovědy v horní navigační liště',
      'support_and_management': 'Подпора а о апликаци',
      'about_tagline': 'Učte se vizuálně. Ovládněte natrvalo.',
      'next_daily_goal_desc': 'Cílový počet karet k osvojení každý den. Změny vstoupí v platnost zítra.',
      'learn_session_size_desc': 'Počet nových karet k zavedení v jedné učební lekci.',
      'test_session_size_desc': 'Počet karet k přezkoumání v jedné testovací lekci.',
      'options_count_desc': 'Počet odpovědí s výběrem z více možností zobrazených během testů.',
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
    },
    'et': {
      'documentation': 'Dokumentatsioon',
      'show_documentation_btn': 'Näita dokumentatsiooni nuppu',
      'show_documentation_btn_desc': 'Kuva abiikoon ülemisel navigeerimisribal',
      'support_and_management': 'Tugi ja teave',
      'about_tagline': 'Õpi visuaalselt. Valda püsivalt.',
      'next_daily_goal_desc': 'Iga päev omandatavate kaartide sihtarv. Muudatused jõustuvad homme.',
      'learn_session_size_desc': 'Ühes õppesessioonis tutvustatavate uute kaartide arv.',
      'test_session_size_desc': 'Ühes kontrollsessioonis ülevaadatavate kaartide arv.',
      'options_count_desc': 'Testide ajal kuvatavate valikvastuste arv.',
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
    },
    'fr': {
      'documentation': 'Documentation',
      'show_documentation_btn': 'Afficher le bouton de documentation',
      'show_documentation_btn_desc': 'Afficher une icône d\'aide dans la barre de navigation supérieure',
      'support_and_management': 'Support et À propos',
      'about_tagline': 'Apprenez visuellement. Maîtrisez durablement.',
      'next_daily_goal_desc': 'Nombre cible de cartes à maîtriser chaque jour. Les modifications prendront effet demain.',
      'learn_session_size_desc': 'Nombre de nouvelles cartes à introduire dans une seule session d\'apprentissage.',
      'test_session_size_desc': 'Nombre de cartes à réviser dans une seule session de test.',
      'options_count_desc': 'Nombre de réponses à choix multiples affichées lors des tests.',
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
      'options_count_desc': 'A tesztek során megjelenített feleletválasztós válaszok száma.',
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
    },
    'pl': {
      'documentation': 'Dokumentacja',
      'show_documentation_btn': 'Pokaż przycisk dokumentacji',
      'show_documentation_btn_desc': 'Wyświetl ikonę pomocy w górnym pasku nawigacyjnym',
      'support_and_management': 'Wsparcie i informacje',
      'about_tagline': 'Ucz się wizualnie. Opanuj na zawsze.',
      'next_daily_goal_desc': 'Docelowa liczba kart do opanowania każdego dnia. Zmiany wejdą w życie jutro.',
      'learn_session_size_desc': 'Liczba nowych kart do wprowadzenia w jednej sesji nauki.',
      'test_session_size_desc': 'Liczba kart do powtórzenia w jednej sesji testowej.',
      'options_count_desc': 'Liczba odpowiedzi wielokrotnego wyboru wyświetlanych podczas testów.',
    },
    'pt': {
      'documentation': 'Documentação',
      'show_documentation_btn': 'Mostrar botón de documentación',
      'show_documentation_btn_desc': 'Exibir um ícone de ayuda en la barra de navigação superior',
      'support_and_management': 'Suporte e Sobre',
      'about_tagline': 'Aprenda visualmente. Domine para siempre.',
      'next_daily_goal_desc': 'Número alvo de cartões para dominar todos os dias. As alterações entram em vigor amanhã.',
      'learn_session_size_desc': 'Número de novos cartões a introduzir numa única sessão de aprendizagem.',
      'test_session_size_desc': 'Número de cartões a rever numa única sessão de teste.',
      'options_count_desc': 'Número de respostas de escolha múltipla apresentadas durante os testes.',
    },
    'ro': {
      'documentation': 'Documentație',
      'show_documentation_btn': 'Afișează butonul de documentație',
      'show_documentation_btn_desc': 'Afișează o pictogramă de ajutor în bara de navigare superioară',
      'support_and_management': 'Suport și Despre',
      'about_tagline': 'Învață vizual. Stăpânește permanent.',
      'next_daily_goal_desc': 'Numărul țintă de carduri de stăpânit în fiecare zi. Modificările intră în vigoare mâine.',
      'learn_session_size_desc': 'Numărul de carduri noi de introdus într-o singură sesiune de învățare.',
      'test_session_size_desc': 'Numărul de carduri de revizuit într-o singură sesiune de testare.',
      'options_count_desc': 'Numărul de răspunsuri cu alegere multiplă afișate în timpul testelor.',
    },
    'sk': {
      'documentation': 'Dokumentácia',
      'show_documentation_btn': 'Zobraziť tlačidlo dokumentácie',
      'show_documentation_btn_desc': 'Zobraziť ikonu pomocníka v hornej navigačnej lište',
      'support_and_management': 'Подпора а о апликаци',
      'about_tagline': 'Učte sa vizuálne. Ovládnite navždy.',
      'next_daily_goal_desc': 'Cieľový počet kariet, ktoré si treba každý deň osvojiť. Zmeny nadobudnú účinnosť zajtra.',
      'learn_session_size_desc': 'Počet nových kariet, ktoré sa majú zaviesť v jednej lekcii učenia.',
      'test_session_size_desc': 'Počet kariet, ktoré sa majú skontrolovať v jednej testovacej lekcii.',
      'options_count_desc': 'Počet odpovedí s výberom z viacerých možností zobrazených počas testov.',
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
    },
    'vi': {
      'documentation': 'Tài liệu',
      'show_documentation_btn': 'Hiển thị nút tài liệu',
      'show_documentation_btn_desc': 'Hiển thị biểu tượng trợ giúp dalam thanh điều hướng trên cùng',
      'support_and_management': 'Hỗ trợ & Giới thiệu',
      'about_tagline': 'Học bằng hình ảnh. Làm chủ mãi mãi.',
      'next_daily_goal_desc': 'Số lượng thẻ mục tiêu cần nắm vững mỗi ngày. Thay đổi có hiệu lực từ ngày mai.',
      'learn_session_size_desc': 'Số lượng thẻ mới cần giới thiệu trong một phiên học.',
      'test_session_size_desc': 'Số lượng thẻ cần ôn tập trong một phiên kiểm tra.',
      'options_count_desc': 'Số lượng câu trả lời trắc nghiệm được hiển thị trong các bài kiểm tra.',
    },
    'tr': {
      'documentation': 'Dokümantasyon',
      'show_documentation_btn': 'Dokümantasyon Butonunu Göster',
      'show_documentation_btn_desc': 'Üst navigasyon çubuğunda bir yardım simgesi görüntüle',
      'support_and_management': 'Destek ve Hakkında',
      'about_tagline': 'Görselle Öğren. Kalıcı Olarak Ustalaş.',
      'next_daily_goal_desc': 'Her gün ustalaşılacak hedef card sayısı. Değişiklikler yarın yürürlüğe girecek.',
      'learn_session_size_desc': 'Tek bir öğrenme oturumunda tanıtılacak yeni kart sayısı.',
      'test_session_size_desc': 'Tek bir test oturumunda gözden geçirilecek kart sayısı.',
      'options_count_desc': 'Testler sırasında görüntülenen çoktan seçmeli cevap sayısı.',
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
    },
    'hi': {
      'documentation': 'दस्तावेज़ीकरण',
      'show_documentation_btn': 'दस्तावेज़ीकरण बटन दिखाएं',
      'show_documentation_btn_desc': 'शीर्ष नेвиगेशन बार में सहायता आइकन प्रदर्शित करें',
      'support_and_management': 'सहायта और जानकारी',
      'about_tagline': 'विज़ुअली सीखें। स्थायी महारत पाएं।',
      'next_daily_goal_desc': 'प्रत्येक दिन महारत हासिल करने के लिए कार्डों की लक्षित संख्या। परिवर्तन कल से प्रभावी होंगे।',
      'learn_session_size_desc': 'एकल शिक्षण सत्र में पेश किए जाने वाले नए कार्डों की संख्या।',
      'test_session_size_desc': 'एकल परीक्षण सत्र में समीक्षा किए जाने वाले कार्डों की संख्या।',
      'options_count_desc': 'परीक्षणों के दौरान प्रदर्शित बहुविकल्पीय उत्तरों की संख्या।',
    },
    'zh': {
      'documentation': '文档',
      'show_documentation_btn': '显示文档按钮',
      'show_documentation_btn_desc': '在顶部导航栏显示帮助图标',
      'support_and_management': '支持与关于',
      'about_tagline': '视觉学习，终身掌握。',
      'next_daily_goal_desc': '每日计划掌握的卡片目标数量。更改将于明天生效。',
      'learn_session_size_desc': '单个学习环节中引入的新卡片数量。',
      'test_session_size_desc': '单个测试环节中复习的卡片数量。',
      'options_count_desc': '测试期间显示的多选题答案数量。',
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
    },
    'ko': {
      'documentation': '문서',
      'show_documentation_btn': '문서 버튼 표시',
      'show_documentation_btn_desc': '상단 내비게이션 바에 도움말 아이콘 표시',
      'support_and_management': '지원 및 정보',
      'about_tagline': '시각적으로 배우고 영원히 마스터하세요.',
      'next_daily_goal_desc': '매일 마스터할 카드 목표 수입니다. 변경 사항은 내일부터 적용됩니다.',
      'learn_session_size_desc': '단일 학습 세션에서 도입할 새 카드의 수입니다.',
      'test_session_size_desc': '단일 테스트 세션에서 검토할 카드의 수입니다.',
      'options_count_desc': '테스트 중 표시되는 객관식 답변 수입니다.',
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
