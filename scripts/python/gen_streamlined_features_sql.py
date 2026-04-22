import json

data = {
  "en": {
    "feature_creation": "Creation Tools",
    "feature_testing": "Interactive Testing",
    "feature_customize": "Advanced Customization",
    "feature_full_library": "Full Library Access"
  },
  "id": {
    "feature_creation": "Alat Pembuatan",
    "feature_testing": "Pengujian Interaktif",
    "feature_customize": "Kustomisasi Lanjutan",
    "feature_full_library": "Akses Perpustakaan Penuh"
  },
  "bg": {
    "feature_creation": "Инструменти за създаване",
    "feature_testing": "Интерактивно тестване",
    "feature_customize": "Разширено персонализиране",
    "feature_full_library": "Пълен достъп до библиотеката"
  },
  "cs": {
    "feature_creation": "Nástroje pro tvorbu",
    "feature_testing": "Interaktivní testování",
    "feature_customize": "Pokročilé přizpůsobení",
    "feature_full_library": "Úplný přístup do knihovny"
  },
  "da": {
    "feature_creation": "Skabelsesværktøjer",
    "feature_testing": "Interaktiv testning",
    "feature_customize": "Avanceret tilpasning",
    "feature_full_library": "Fuld adgang til biblioteket"
  },
  "de": {
    "feature_creation": "Erstellungstools",
    "feature_testing": "Interaktives Testen",
    "feature_customize": "Erweiterte Anpassung",
    "feature_full_library": "Vollständiger Bibliothekszugriff"
  },
  "et": {
    "feature_creation": "Loomise tööriistad",
    "feature_testing": "Interaktiivne testimine",
    "feature_customize": "Täpsem kohandamine",
    "feature_full_library": "Täielik juurdepääs raamatukogule"
  },
  "es": {
    "feature_creation": "Herramientas de creación",
    "feature_testing": "Pruebas interactivas",
    "feature_customize": "Personalización avanzada",
    "feature_full_library": "Acceso completo a la biblioteca"
  },
  "fr": {
    "feature_creation": "Outils de création",
    "feature_testing": "Tests interactifs",
    "feature_customize": "Personnalisation avancée",
    "feature_full_library": "Accès complet à la bibliothèque"
  },
  "ga": {
    "feature_creation": "Uirlisí Cruthaithe",
    "feature_testing": "Tástáil Idirghníomhach",
    "feature_customize": "Saincheapadh Casta",
    "feature_full_library": "Rochtain Iomlán ar an Leabharlann"
  },
  "hr": {
    "feature_creation": "Alati za stvaranje",
    "feature_testing": "Interaktivno testiranje",
    "feature_customize": "Napredno prilagođavanje",
    "feature_full_library": "Puni pristup knjižnici"
  },
  "it": {
    "feature_creation": "Strumenti di creazione",
    "feature_testing": "Test interattivi",
    "feature_customize": "Personalizzazione avanzada",
    "feature_full_library": "Accesso completo alla biblioteca"
  },
  "lv": {
    "feature_creation": "Veidošanas rīki",
    "feature_testing": "Interaktīvā testēšana",
    "feature_customize": "Uzlabota pielāgošana",
    "feature_full_library": "Pilna piekļuve bibliotēkai"
  },
  "lt": {
    "feature_creation": "Kūrimo įrankiai",
    "feature_testing": "Interaktyvus testavimas",
    "feature_customize": "Išplėstinis pritaikymas",
    "feature_full_library": "Visiška prieiga prie bibliotekos"
  },
  "hu": {
    "feature_creation": "Létrehozási eszközök",
    "feature_testing": "Interaktív tesztelés",
    "feature_customize": "Speciális testreszabás",
    "feature_full_library": "Teljes könyvtári hozzáférés"
  },
  "mt": {
    "feature_creation": "Għodod tal-Ħolqien",
    "feature_testing": "Ittestjar Interattiv",
    "feature_customize": "Personalizzazzjoni Avvanzata",
    "feature_full_library": "Aċċess Sħiħ għal-Librerija"
  },
  "nl": {
    "feature_creation": "Creatietools",
    "feature_testing": "Interactief testen",
    "feature_customize": "Geavanceerde aanpassing",
    "feature_full_library": "Volledige bibliotheektoegang"
  },
  "pl": {
    "feature_creation": "Narzędzia do tworzenia",
    "feature_testing": "Testy interaktywne",
    "feature_customize": "Zaawansowana personalizacja",
    "feature_full_library": "Pełny dostęp do biblioteki"
  },
  "pt": {
    "feature_creation": "Ferramentas de criação",
    "feature_testing": "Testes interativos",
    "feature_customize": "Personalização avançada",
    "feature_full_library": "Acesso total à biblioteca"
  },
  "ro": {
    "feature_creation": "Instrumente de creare",
    "feature_testing": "Testare interactivă",
    "feature_customize": "Personalizare avansată",
    "feature_full_library": "Acces complet la bibliotecă"
  },
  "sk": {
    "feature_creation": "Nástroje na tvorbu",
    "feature_testing": "Interaktívne testovanie",
    "feature_customize": "Pokročilé prispôsobenie",
    "feature_full_library": "Úplný prístup do knižnice"
  },
  "sl": {
    "feature_creation": "Orodja za ustvarjanje",
    "feature_testing": "Interaktivno testiranje",
    "feature_customize": "Napredna prilagoditev",
    "feature_full_library": "Popoln dostup do knjižnice"
  },
  "fi": {
    "feature_creation": "Luontityökalut",
    "feature_testing": "Interaktiivinen testaus",
    "feature_customize": "Edistynyt muokkaus",
    "feature_full_library": "Täysi pääsy kirjastoon"
  },
  "sv": {
    "feature_creation": "Skaparverktyg",
    "feature_testing": "Interaktiv testning",
    "feature_customize": "Avancerad anpassning",
    "feature_full_library": "Full tillgång till biblioteket"
  },
  "tl": {
    "feature_creation": "Mga Tool sa Paglikha",
    "feature_testing": "Interactive na Pagsusulit",
    "feature_customize": "Advanced na Pag-customize",
    "feature_full_library": "Ganap na Akses sa Library"
  },
  "vi": {
    "feature_creation": "Công cụ sáng tạo",
    "feature_testing": "Kiểm tra tương tác",
    "feature_customize": "Tùy chỉnh nâng cao",
    "feature_full_library": "Truy cập thư viện đầy đủ"
  },
  "tr": {
    "feature_creation": "Oluşturma Araçları",
    "feature_testing": "İnteraktif Test",
    "feature_customize": "Gelişmiş Özelleştirme",
    "feature_full_library": "Tam Kütüphane Erişimi"
  },
  "el": {
    "feature_creation": "Εργαλεία Δημιουργίας",
    "feature_testing": "Διαδραστική Δοκιμή",
    "feature_customize": "Προηγμένη Προσαρμογή",
    "feature_full_library": "Πλήρης Πρόσβαση στη Βιβλιοθήκη"
  },
  "uk": {
    "feature_creation": "Інструменти створення",
    "feature_testing": "Інтерактивне тестування",
    "feature_customize": "Розширене налаштування",
    "feature_full_library": "Повний доступ до бібліотеки"
  },
  "ar": {
    "feature_creation": "أدوات الإنشاء",
    "feature_testing": "اختبار تفاعلي",
    "feature_customize": "تخصيص متقدم",
    "feature_full_library": "وصول كامل للمكتبة"
  },
  "hi": {
    "feature_creation": "निर्माण उपकरण",
    "feature_testing": "इंटरएक्टिव परीक्षण",
    "feature_customize": "उन्नत अनुकूलन",
    "feature_full_library": "पूर्ण पुस्तकालय पहुंच"
  },
  "zh": {
    "feature_creation": "创建工具",
    "feature_testing": "互动测试",
    "feature_customize": "高级定制",
    "feature_full_library": "完整库访问权限"
  },
  "ja": {
    "feature_creation": "作成ツール",
    "feature_testing": "インタラクティブ・テスト",
    "feature_customize": "高度なカスタマイズ",
    "feature_full_library": "フルライブラリ・アクセス"
  },
  "ko": {
    "feature_creation": "제작 도구",
    "feature_testing": "대화형 테스트",
    "feature_customize": "고급 사용자 정의",
    "feature_full_library": "전체 라이브러리 액세스"
  }
}

sql_commands = []
for lang, keys in data.items():
    for key, translation in keys.items():
        escaped_translation = translation.replace("'", "''")
        sql_commands.append(f"INSERT OR REPLACE INTO ui_translations (key, lang, value, updated_at) VALUES ('{key}', '{lang}', '{escaped_translation}', CURRENT_TIMESTAMP);")

full_sql = "\n".join(sql_commands)
with open("scripts/sql/update_features_streamlined.sql", "w") as f:
    f.write(full_sql)

print("SQL script generated at scripts/sql/update_features_streamlined.sql")
