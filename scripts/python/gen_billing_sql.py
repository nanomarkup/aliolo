import json

translations = {
  "en": {
    "plan_weekly_title": "Weekly Access",
    "plan_monthly_title": "Monthly Access",
    "plan_yearly_title": "Yearly Access",
    "plan_weekly_tagline": "Best for quick goals",
    "plan_monthly_tagline": "Most popular choice",
    "plan_yearly_tagline": "Save 33% per month"
  },
  "id": {
    "plan_weekly_title": "Akses Mingguan",
    "plan_monthly_title": "Akses Bulanan",
    "plan_yearly_title": "Akses Tahunan",
    "plan_weekly_tagline": "Terbaik untuk tujuan cepat",
    "plan_monthly_tagline": "Pilihan paling populer",
    "plan_yearly_tagline": "Hemat 33% per bulan"
  },
  "bg": {
    "plan_weekly_title": "Седмичен достъп",
    "plan_monthly_title": "Месечен достъп",
    "plan_yearly_title": "Годишен достъп",
    "plan_weekly_tagline": "Най-доброто за бързи голове",
    "plan_monthly_tagline": "Най-популярният избор",
    "plan_yearly_tagline": "Спестете 33% на месец"
  },
  "cs": {
    "plan_weekly_title": "Týdenní přístup",
    "plan_monthly_title": "Měsíční přístup",
    "plan_yearly_title": "Roční přístup",
    "plan_weekly_tagline": "Nejlepší na rychlé góly",
    "plan_monthly_tagline": "Nejoblíbenější volba",
    "plan_yearly_tagline": "Ušetřete 33 % měsíčně"
  },
  "da": {
    "plan_weekly_title": "Ugentlig adgang",
    "plan_monthly_title": "Månedlig adgang",
    "plan_yearly_title": "Årlig adgang",
    "plan_weekly_tagline": "Bedst til hurtige mål",
    "plan_monthly_tagline": "Mest populære valg",
    "plan_yearly_tagline": "Spar 33% om måneden"
  },
  "de": {
    "plan_weekly_title": "Wöchentlicher Zugriff",
    "plan_monthly_title": "Monatlicher Zugriff",
    "plan_yearly_title": "Jährlicher Zugang",
    "plan_weekly_tagline": "Am besten für schnelle Ziele",
    "plan_monthly_tagline": "Beliebteste Wahl",
    "plan_yearly_tagline": "Sparen Sie 33 % pro Monat"
  },
  "et": {
    "plan_weekly_title": "Iganädalane juurdepääs",
    "plan_monthly_title": "Igakuine juurdepääs",
    "plan_yearly_title": "Aastane juurdepääs",
    "plan_weekly_tagline": "Parim kiirete eesmärkide saavutamiseks",
    "plan_monthly_tagline": "Kõige populaarsem valik",
    "plan_yearly_tagline": "Säästa 33% kuus"
  },
  "es": {
    "plan_weekly_title": "Acceso Semanal",
    "plan_monthly_title": "Acceso Mensual",
    "plan_yearly_title": "Acceso Anual",
    "plan_weekly_tagline": "Lo mejor para objetivos rápidos",
    "plan_monthly_tagline": "Elección más popular",
    "plan_yearly_tagline": "Ahorre 33% por mes"
  },
  "fr": {
    "plan_weekly_title": "Accès hebdomadaire",
    "plan_monthly_title": "Accès mensuel",
    "plan_yearly_title": "Accès annuel",
    "plan_weekly_tagline": "Idéal pour les objectifs rapides",
    "plan_monthly_tagline": "Choix le plus populaire",
    "plan_yearly_tagline": "Économisez 33 % par mois"
  },
  "ga": {
    "plan_weekly_title": "Rochtain Seachtainiúil",
    "plan_monthly_title": "Rochtain Mhíosúil",
    "plan_yearly_title": "Rochtain Bhliantúil",
    "plan_weekly_tagline": "Is fearr le haghaidh spriocanna tapa",
    "plan_monthly_tagline": "Rogha is coitianta",
    "plan_yearly_tagline": "Sábháil 33% in aghaidh na míosa"
  },
  "hr": {
    "plan_weekly_title": "Tjedni pristup",
    "plan_monthly_title": "Mjesečni pristup",
    "plan_yearly_title": "Godišnji pristup",
    "plan_weekly_tagline": "Najbolji za brze golove",
    "plan_monthly_tagline": "Najpopularniji izbor",
    "plan_yearly_tagline": "Uštedite 33% mjesečno"
  },
  "it": {
    "plan_weekly_title": "Accesso settimanale",
    "plan_monthly_title": "Accesso mensile",
    "plan_yearly_title": "Accesso annuale",
    "plan_weekly_tagline": "Ideale per obiettivi rapidi",
    "plan_monthly_tagline": "La scelta più popolare",
    "plan_yearly_tagline": "Risparmia il 33% al mese"
  },
  "lv": {
    "plan_weekly_title": "Iknedēļas piekļuve",
    "plan_monthly_title": "Ikmēneša piekļuve",
    "plan_yearly_title": "Ikgadējā piekļuve",
    "plan_weekly_tagline": "Vislabāk ātriem mērķiem",
    "plan_monthly_tagline": "Populārākā izvēle",
    "plan_yearly_tagline": "Ietaupiet 33% mēnesī"
  },
  "lt": {
    "plan_weekly_title": "Savaitinė prieiga",
    "plan_monthly_title": "Mėnesinė prieiga",
    "plan_yearly_title": "Kasmetinė prieiga",
    "plan_weekly_tagline": "Geriausiai tinka greitiems įvarčiams",
    "plan_monthly_tagline": "Populiariausias pasirinkimas",
    "plan_yearly_tagline": "Sutauvykite 33% per mėnesį"
  },
  "hu": {
    "plan_weekly_title": "Heti hozzáférés",
    "plan_monthly_title": "Havi hozzáférés",
    "plan_yearly_title": "Éves hozzáférés",
    "plan_weekly_tagline": "Legjobb gyors gólokhoz",
    "plan_monthly_tagline": "A legnépszerűbb választás",
    "plan_yearly_tagline": "33% megtakarítás havonta"
  },
  "mt": {
    "plan_weekly_title": "Aċċess ta' kull ġimgħa",
    "plan_monthly_title": "Aċċess ta' Kull Xahar",
    "plan_yearly_title": "Aċċess annwali",
    "plan_weekly_tagline": "L-aħjar għal għanijiet ta' malajr",
    "plan_monthly_tagline": "L-aktar għażla popolari",
    "plan_yearly_tagline": "Iffranka 33% fix-xahar"
  },
  "nl": {
    "plan_weekly_title": "Wekelijkse toegang",
    "plan_monthly_title": "Maandelijkse toegang",
    "plan_yearly_title": "Jaarlijkse toegang",
    "plan_weekly_tagline": "Beste voor snelle doelpunten",
    "plan_monthly_tagline": "Meest populaire keuze",
    "plan_yearly_tagline": "Bespaar 33% per maand"
  },
  "pl": {
    "plan_weekly_title": "Dostęp tygodniowy",
    "plan_monthly_title": "Dostęp miesięczny",
    "plan_yearly_title": "Dostęp roczny",
    "plan_weekly_tagline": "Najlepszy do szybkich bramek",
    "plan_monthly_tagline": "Najpopularniejszy wybór",
    "plan_yearly_tagline": "Oszczędzaj 33% miesięcznie"
  },
  "pt": {
    "plan_weekly_title": "Acesso Semanal",
    "plan_monthly_title": "Acesso Mensual",
    "plan_yearly_title": "Acesso Anual",
    "plan_weekly_tagline": "Melhor para metas rápidas",
    "plan_monthly_tagline": "Escolha mais popular",
    "plan_yearly_tagline": "Economize 33% ao mês"
  },
  "ro": {
    "plan_weekly_title": "Acces săptămânal",
    "plan_monthly_title": "Acces lunar",
    "plan_yearly_title": "Acces anual",
    "plan_weekly_tagline": "Cel mai bun pentru goluri rapide",
    "plan_monthly_tagline": "Cea mai populară alegere",
    "plan_yearly_tagline": "Economisiți 33% pe lună"
  },
  "sk": {
    "plan_weekly_title": "Týždenný prístup",
    "plan_monthly_title": "Mesačný prístup",
    "plan_yearly_title": "Ročný prístup",
    "plan_weekly_tagline": "Najlepšie na rýchle góly",
    "plan_monthly_tagline": "Najobľúbenejšia voľba",
    "plan_yearly_tagline": "Ušetrite 33% mesačne"
  },
  "sl": {
    "plan_weekly_title": "Tedenski dostop",
    "plan_monthly_title": "Mesečni dostop",
    "plan_yearly_title": "Letni dostop",
    "plan_weekly_tagline": "Najboljši za hitre gole",
    "plan_monthly_tagline": "Najbolj priljubljena izbira",
    "plan_yearly_tagline": "Prihranite 33 % na mesec"
  },
  "fi": {
    "plan_weekly_title": "Viikoittainen pääsy",
    "plan_monthly_title": "Kuukausittainen pääsy",
    "plan_yearly_title": "Vuosittainen pääsy",
    "plan_weekly_tagline": "Paras nopeille maaleille",
    "plan_monthly_tagline": "Suosituin valinta",
    "plan_yearly_tagline": "Säästä 33 % kuukaudessa"
  },
  "sv": {
    "plan_weekly_title": "Veckovis tillgång",
    "plan_monthly_title": "Månatlig tillgång",
    "plan_yearly_title": "Årlig tillgång",
    "plan_weekly_tagline": "Bäst för snabba mål",
    "plan_monthly_tagline": "Mest populära valet",
    "plan_yearly_tagline": "Spara 33 % per månad"
  },
  "tl": {
    "plan_weekly_title": "Lingguhang Access",
    "plan_monthly_title": "Buwanang Access",
    "plan_yearly_title": "Taunang Access",
    "plan_weekly_tagline": "Pinakamahusay para sa mabilis na layunin",
    "plan_monthly_tagline": "Pinakatanyag na pagpipilian",
    "plan_yearly_tagline": "Makatipid ng 33% bawat buwan"
  },
  "vi": {
    "plan_weekly_title": "Truy cập hàng tuần",
    "plan_monthly_title": "Truy cập hàng tháng",
    "plan_yearly_title": "Truy cập hàng năm",
    "plan_weekly_tagline": "Tốt nhất cho mục tiêu nhanh chóng",
    "plan_monthly_tagline": "Sự lựa chọn phổ biến nhất",
    "plan_yearly_tagline": "Tiết kiệm 33% mỗi tháng"
  },
  "tr": {
    "plan_weekly_title": "Haftalık Erişim",
    "plan_monthly_title": "Aylık Erişim",
    "plan_yearly_title": "Yıllık Erişim",
    "plan_weekly_tagline": "Hızlı hedefler için en iyisi",
    "plan_monthly_tagline": "En popüler seçim",
    "plan_yearly_tagline": "Ayda %33 tasarruf edin"
  },
  "el": {
    "plan_weekly_title": "Εβδομαδιαία πρόσβαση",
    "plan_monthly_title": "Μηνιαία πρόσβαση",
    "plan_yearly_title": "Ετήσια πρόσβαση",
    "plan_weekly_tagline": "Το καλύτερο για γρήγορους στόχους",
    "plan_monthly_tagline": "Η πιο δημοφιλής επιλογή",
    "plan_yearly_tagline": "Εξοικονομήστε 33% ανά μήνα"
  },
  "uk": {
    "plan_weekly_title": "Щотижневий доступ",
    "plan_monthly_title": "Щомісячний доступ",
    "plan_yearly_title": "Річний доступ",
    "plan_weekly_tagline": "Найкраще для швидких голів",
    "plan_monthly_tagline": "Найпопулярніший вибір",
    "plan_yearly_tagline": "Економія 33% на місяць"
  },
  "ar": {
    "plan_weekly_title": "الوصول الأسبوعي",
    "plan_monthly_title": "الوصول الشهري",
    "plan_yearly_title": "الوصول السنوي",
    "plan_weekly_tagline": "الأفضل للأهداف السريعة",
    "plan_monthly_tagline": "الاختيار الأكثر شعبية",
    "plan_yearly_tagline": "وفر 33% شهريًا"
  },
  "hi": {
    "plan_weekly_title": "साप्ताहिक प्रवेश",
    "plan_monthly_title": "मासिक प्रवेश",
    "plan_yearly_title": "वार्षिक प्रवेश",
    "plan_weekly_tagline": "त्वरित लक्ष्यों के लिए सर्वोत्तम",
    "plan_monthly_tagline": "सबसे लोकप्रिय विकल्प",
    "plan_yearly_tagline": "प्रति माह 33% बचाएं"
  },
  "zh": {
    "plan_weekly_title": "每周访问",
    "plan_monthly_title": "每月访问",
    "plan_yearly_title": "每年访问",
    "plan_weekly_tagline": "最适合快速目标",
    "plan_monthly_tagline": "最受欢迎的选择",
    "plan_yearly_tagline": "每月节省 33%"
  },
  "ja": {
    "plan_weekly_title": "週間アクセス",
    "plan_monthly_title": "月間アクセス数",
    "plan_yearly_title": "年間アクセス",
    "plan_weekly_tagline": "素早い目標に最適",
    "plan_monthly_tagline": "最も人気のある選択肢",
    "plan_yearly_tagline": "毎月 33% 割引"
  },
  "ko": {
    "plan_weekly_title": "주간 액세스",
    "plan_monthly_title": "월간 액세스",
    "plan_yearly_title": "연간 액세스",
    "plan_weekly_tagline": "빠른 목표에 가장 적합",
    "plan_monthly_tagline": "가장 인기있는 선택",
    "plan_yearly_tagline": "월 33% 할인"
  }
}

sql_commands = []
for lang, keys in translations.items():
    for key, translation in keys.items():
        escaped_translation = translation.replace("'", "''")
        sql_commands.append(f"INSERT OR REPLACE INTO ui_translations (key, lang, value, updated_at) VALUES ('{key}', '{lang}', '{escaped_translation}', CURRENT_TIMESTAMP);")

full_sql = "\n".join(sql_commands)
with open("scripts/sql/update_billing_details_ui.sql", "w") as f:
    f.write(full_sql)
