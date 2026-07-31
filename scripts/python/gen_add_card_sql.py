import json
import os

data_str = """
{
  "en": {
    "renderer": "Renderer",
    "visual_text": "Visual Text",
    "no_images_added": "No images added",
    "audio": "Audio",
    "no_localized_audio": "No localized audio",
    "no_localized_video": "No localized video",
    "visual_content_required": "At least one visual content is required",
    "visual_content_required_msg": "At least one visual content (text, image, audio, or video) must be provided."
  },
  "id": {
    "renderer": "Perender",
    "visual_text": "Teks Visual",
    "no_images_added": "Tidak ada gambar yang ditambahkan",
    "audio": "Audio",
    "no_localized_audio": "Tidak ada audio yang dilokalkan",
    "no_localized_video": "Tidak ada video yang dilokalkan",
    "visual_content_required": "Setidaknya satu konten visual diperlukan",
    "visual_content_required_msg": "Setidaknya satu konten visual (teks, gambar, audio, atau video) harus disediakan."
  },
  "bg": {
    "renderer": "Рендерер",
    "visual_text": "Визуален текст",
    "no_images_added": "Няма добавени изображения",
    "audio": "Аудио",
    "no_localized_audio": "Няма локализирано аудио",
    "no_localized_video": "Няма локализирано видео",
    "visual_content_required": "Изисква се поне едно визуално съдържание",
    "visual_content_required_msg": "Трябва да бъде предоставено поне едно визуално съдържание (текст, изображение, аудио или видео)."
  },
  "cs": {
    "renderer": "Vykreslovací modul",
    "visual_text": "Vizuální text",
    "no_images_added": "Nebyly přidány žádné obrázky",
    "audio": "Zvuk",
    "no_localized_audio": "Žádný lokalizovaný zvuk",
    "no_localized_video": "Žádné lokalizované video",
    "visual_content_required": "Je vyžadován alespoň jeden vizuální obsah",
    "visual_content_required_msg": "Musí být poskytnut alespoň jeden vizuální obsah (text, obrázek, zvuk nebo video)."
  },
  "da": {
    "renderer": "Gengiver",
    "visual_text": "Visuel tekst",
    "no_images_added": "Ingen billeder tilføjet",
    "audio": "Lyd",
    "no_localized_audio": "Ingen lokaliseret lyd",
    "no_localized_video": "Ingen lokaliseret video",
    "visual_content_required": "Mindst ét visuelt indhold er påkrævet",
    "visual_content_required_msg": "Der skal angives mindst ét visuelt indhold (tekst, billede, lyd eller video)."
  },
  "de": {
    "renderer": "Renderer",
    "visual_text": "Visueller Text",
    "no_images_added": "Keine Bilder hinzugefügt",
    "audio": "Audio",
    "no_localized_audio": "Kein lokalisiertes Audio",
    "no_localized_video": "Kein lokalisiertes Video",
    "visual_content_required": "Mindestens ein visueller Inhalt ist erforderlich",
    "visual_content_required_msg": "Mindestens ein visueller Inhalt (Text, Bild, Audio oder Video) muss bereitgestellt werden."
  },
  "et": {
    "renderer": "Renderdaja",
    "visual_text": "Visuaalne tekst",
    "no_images_added": "Pilte pole lisatud",
    "audio": "Heli",
    "no_localized_audio": "Lokaliseeritud heli pole",
    "no_localized_video": "Lokaliseeritud videot pole",
    "visual_content_required": "Vaja on vähemalt ühte visuaalset sisu",
    "visual_content_required_msg": "Esitada tuleb vähemalt üks visuaalne sisu (tekst, pilt, heli või video)."
  },
  "es": {
    "renderer": "Renderizador",
    "visual_text": "Texto visual",
    "no_images_added": "No se han añadido imágenes",
    "audio": "Audio",
    "no_localized_audio": "Sin audio localizado",
    "no_localized_video": "Sin vídeo localizado",
    "visual_content_required": "Se requiere al menos un contenido visual",
    "visual_content_required_msg": "Se debe proporcionar al menos un contenido visual (texto, imagen, audio o vídeo)."
  },
  "fr": {
    "renderer": "Moteur de rendu",
    "visual_text": "Texte visuel",
    "no_images_added": "Aucune image ajoutée",
    "audio": "Audio",
    "no_localized_audio": "Aucun audio localisé",
    "no_localized_video": "Aucune vidéo localisée",
    "visual_content_required": "Au moins un contenu visuel est requis",
    "visual_content_required_msg": "Au moins un contenu visuel (texte, image, audio ou vidéo) doit être fourni."
  },
  "ga": {
    "renderer": "Rindreálaí",
    "visual_text": "Téacs Físiúil",
    "no_images_added": "Níor cuireadh aon íomhánna leis",
    "audio": "Fuaim",
    "no_localized_audio": "Gan aon fhuaim logánta",
    "no_localized_video": "Gan aon fhíseán logánta",
    "visual_content_required": "Tá gá le hábhar físiúil amháin ar a laghad",
    "visual_content_required_msg": "Ní mór ábhar físiúil amháin ar a laghad (téacs, íomhá, fuaim nó físeán) a sholáthar."
  },
  "hr": {
    "renderer": "Prikazivač",
    "visual_text": "Vizualni tekst",
    "no_images_added": "Nema dodanih slika",
    "audio": "Audio",
    "no_localized_audio": "Nema lokaliziranog zvuka",
    "no_localized_video": "Nema lokaliziranog videa",
    "visual_content_required": "Potreban je barem jedan vizualni sadržaj",
    "visual_content_required_msg": "Mora se navesti barem jedan vizualni sadržaj (tekst, slika, zvuk ili video)."
  },
  "it": {
    "renderer": "Renderer",
    "visual_text": "Testo visivo",
    "no_images_added": "Nessuna immagine aggiunta",
    "audio": "Audio",
    "no_localized_audio": "Nessun audio localizzato",
    "no_localized_video": "Nessun video localizzato",
    "visual_content_required": "È richiesto almeno un contenuto visivo",
    "visual_content_required_msg": "Deve essere fornito almeno un contenuto visivo (testo, immagine, audio o video)."
  },
  "lv": {
    "renderer": "Renderētājs",
    "visual_text": "Vizuālais teksts",
    "no_images_added": "Nav pievienotu attēlu",
    "audio": "Audio",
    "no_localized_audio": "Nav lokalizēta audio",
    "no_localized_video": "Nav lokalizēta video",
    "visual_content_required": "Nepieciešams vismaz viens vizuālais saturs",
    "visual_content_required_msg": "Jānorāda vismaz viens vizuālais saturs (teksts, attēls, audio vai video)."
  },
  "lt": {
    "renderer": "Atvaizdavimo modulis",
    "visual_text": "Vaizdinis tekstas",
    "no_images_added": "Nepridėta jokių vaizdų",
    "audio": "Garsas",
    "no_localized_audio": "Nėra lokalizuoto garso",
    "no_localized_video": "Nėra lokalizuoto vaizdo įrašo",
    "visual_content_required": "Reikalingas bent vienas vizualinis turinys",
    "visual_content_required_msg": "Turi būti pateiktas bent vienas vizualinis turinys (tekstas, vaizdas, garsas arba vaizdo įrašas)."
  },
  "hu": {
    "renderer": "Megjelenítő",
    "visual_text": "Vizuális szöveg",
    "no_images_added": "Nincs kép hozzáadva",
    "audio": "Hang",
    "no_localized_audio": "Nincs lokalizált hang",
    "no_localized_video": "Nincs lokalizált videó",
    "visual_content_required": "Legalább egy vizuális tartalom kötelező",
    "visual_content_required_msg": "Legalább egy vizuális tartalmat (szöveg, kép, hang vagy videó) meg kell adni."
  },
  "mt": {
    "renderer": "Renditur",
    "visual_text": "Test Viżwali",
    "no_images_added": "L-ebda immaġni miżjuda",
    "audio": "Awdjo",
    "no_localized_audio": "L-ebda awdjo lokalizzat",
    "no_localized_video": "L-ebda vidjo lokalizzat",
    "visual_content_required": "Huwa meħtieġ mill-inqas kontenut viżwali wieħed",
    "visual_content_required_msg": "Għandu jiġi pprovdut mill-inqas kontenut viżwali wieħed (test, immaġni, awdjo, jew vidjo)."
  },
  "nl": {
    "renderer": "Renderer",
    "visual_text": "Visuele tekst",
    "no_images_added": "Geen afbeeldingen toegevoegd",
    "audio": "Audio",
    "no_localized_audio": "Geen gelokaliseerde audio",
    "no_localized_video": "Geen gelokaliseerde video",
    "visual_content_required": "Ten minste één visuele inhoud is vereist",
    "visual_content_required_msg": "Er moet ten minste één visuele inhoud (tekst, afbeelding, audio of video) worden opgegeven."
  },
  "pl": {
    "renderer": "Mechanizm renderujący",
    "visual_text": "Tekst wizualny",
    "no_images_added": "Nie dodano żadnych obrazów",
    "audio": "Dźwięk",
    "no_localized_audio": "Brak zlokalizowanego dźwięku",
    "no_localized_video": "Brak zlokalizowanego wideo",
    "visual_content_required": "Wymagana jest co najmniej jedna treść wizualna",
    "visual_content_required_msg": "Należy podać co najmniej jedną treść wizualną (tekst, obraz, dźwięk lub wideo)."
  },
  "pt": {
    "renderer": "Renderizador",
    "visual_text": "Texto visual",
    "no_images_added": "Nenhuma imagem adicionada",
    "audio": "Áudio",
    "no_localized_audio": "Nenhum áudio localizado",
    "no_localized_video": "Nenhum vídeo localizado",
    "visual_content_required": "É necessário pelo menos um conteúdo visual",
    "visual_content_required_msg": "Pelo menos um conteúdo visual (texto, imagem, áudio ou vídeo) deve ser fornecido."
  },
  "ro": {
    "renderer": "Motor de randare",
    "visual_text": "Text vizual",
    "no_images_added": "Nicio imagine adăugată",
    "audio": "Audio",
    "no_localized_audio": "Niciun sunet localizat",
    "no_localized_video": "Niciun videoclip localizat",
    "visual_content_required": "Este necesar cel puțin un conținut vizual",
    "visual_content_required_msg": "Trebuie furnizat cel puțin un conținut vizual (text, imagine, audio sau videoclip)."
  },
  "sk": {
    "renderer": "Vykresľovač",
    "visual_text": "Vizuálny text",
    "no_images_added": "Žiadne pridané obrázky",
    "audio": "Zvuk",
    "no_localized_audio": "Žiadny lokalizovaný zvuk",
    "no_localized_video": "Žiadne lokalizované video",
    "visual_content_required": "Vyžaduje sa aspoň jeden vizuálny obsah",
    "visual_content_required_msg": "Musí sa poskytnúť aspoň jeden vizuálny obsah (text, obrázok, zvuk alebo video)."
  },
  "sl": {
    "renderer": "Upodabljalnik",
    "visual_text": "Vizualno besedilo",
    "no_images_added": "Ni dodanih slik",
    "audio": "Zvok",
    "no_localized_audio": "Ni lokaliziranega zvoka",
    "no_localized_video": "Ni lokaliziranega videa",
    "visual_content_required": "Potrebna je vsaj ena vizualna vsebina",
    "visual_content_required_msg": "Zagotoviti je treba vsaj eno vizualno vsebino (besedilo, slika, zvok ali video)."
  },
  "fi": {
    "renderer": "Renderöijä",
    "visual_text": "Visuaalinen teksti",
    "no_images_added": "Ei lisättyjä kuvia",
    "audio": "Ääni",
    "no_localized_audio": "Ei lokalisoitua ääntä",
    "no_localized_video": "Ei lokalisoitua videota",
    "visual_content_required": "Vähintään yksi visuaalinen sisältö vaaditaan",
    "visual_content_required_msg": "Vähintään yksi visuaalinen sisältö (teksti, kuva, ääni tai video) on annettava."
  },
  "sv": {
    "renderer": "Rendrerare",
    "visual_text": "Visuell text",
    "no_images_added": "Inga bilder har lagts till",
    "audio": "Ljud",
    "no_localized_audio": "Inget lokaliserat ljud",
    "no_localized_video": "Inget lokaliserat videoklipp",
    "visual_content_required": "Minst ett visuellt innehåll krävs",
    "visual_content_required_msg": "Minst ett visuellt innehåll (text, bild, ljud eller video) måste anges."
  },
  "tl": {
    "renderer": "Renderer",
    "visual_text": "Visual Text",
    "no_images_added": "Walang idinagdag na mga larawan",
    "audio": "Audio",
    "no_localized_audio": "Walang naka-localize na audio",
    "no_localized_video": "Walang naka-localize na video",
    "visual_content_required": "Kinakailangan ng hindi bababa sa isang visual content",
    "visual_content_required_msg": "Dapat magbigay ng hindi bababa sa isang visual content (text, larawan, audio, o video)."
  },
  "vi": {
    "renderer": "Trình kết xuất",
    "visual_text": "Văn bản trực quan",
    "no_images_added": "Không có hình ảnh nào được thêm",
    "audio": "Âm thanh",
    "no_localized_audio": "Không có âm thanh được bản địa hóa",
    "no_localized_video": "Không có video được bản địa hóa",
    "visual_content_required": "Yêu cầu ít nhất một nội dung trực quan",
    "visual_content_required_msg": "Phải cung cấp ít nhất một nội dung trực quan (văn bản, hình ảnh, âm thanh hoặc video)."
  },
  "tr": {
    "renderer": "Oluşturucu",
    "visual_text": "Görsel Metin",
    "no_images_added": "Görsel eklenmedi",
    "audio": "Ses",
    "no_localized_audio": "Yerelleştirilmiş ses yok",
    "no_localized_video": "Yerelleştirilmiş video yok",
    "visual_content_required": "En az bir görsel içerik gereklidir",
    "visual_content_required_msg": "En az bir görsel içerik (metin, resim, ses veya video) sağlanmalıdır."
  },
  "el": {
    "renderer": "Απόδοση",
    "visual_text": "Οπτικό κείμενο",
    "no_images_added": "Δεν προστέθηκαν εικόνες",
    "audio": "Ήχος",
    "no_localized_audio": "Δεν υπάρχει τοπικός ήχος",
    "no_localized_video": "Δεν υπάρχει τοπικό βίντεο",
    "visual_content_required": "Απαιτείται τουλάχιστον ένα οπτικό περιεχόμενο",
    "visual_content_required_msg": "Πρέπει να παρέχεται τουλάχιστον ένα οπτικό περιεχόμενο (κείμενο, εικόνα, ήχος ή βίντεο)."
  },
  "uk": {
    "renderer": "Рендерер",
    "visual_text": "Візуальний текст",
    "no_images_added": "Зображення не додано",
    "audio": "Аудіо",
    "no_localized_audio": "Немає локалізованого аудіо",
    "no_localized_video": "Немає локалізованого відео",
    "visual_content_required": "Потрібен принаймні один візуальний вміст",
    "visual_content_required_msg": "Необхідно надати принаймні один візуальний вміст (текст, зображення, аудіо або відео)."
  },
  "ar": {
    "renderer": "العارض",
    "visual_text": "نص مرئي",
    "no_images_added": "لم تتم إضافة أي صور",
    "audio": "صوت",
    "no_localized_audio": "لا يوجد صوت محلي",
    "no_localized_video": "لا يوجد فيديو محلي",
    "visual_content_required": "مطلوب محتوى مرئي واحد على الأقل",
    "visual_content_required_msg": "يجب توفير محتوى مرئي واحد على الأقل (نص أو صورة أو صوت أو فيديو)."
  },
  "hi": {
    "renderer": "रेंडरर",
    "visual_text": "विज़ुअल टेक्स्ट",
    "no_images_added": "कोई चित्र नहीं जोड़ा गया",
    "audio": "ऑडियो",
    "no_localized_audio": "कोई स्थानीयकृत ऑडियो नहीं",
    "no_localized_video": "कोई स्थानीयकृत वीडियो नहीं",
    "visual_content_required": "कम से कम एक विज़ुअल सामग्री आवश्यक है",
    "visual_content_required_msg": "कम से कम एक विज़ुअल सामग्री (टेक्स्ट, छवि, ऑडियो या वीडियो) प्रदान की जानी चाहिए।"
  },
  "zh": {
    "renderer": "渲染器",
    "visual_text": "视觉文本",
    "no_images_added": "未添加图像",
    "audio": "音频",
    "no_localized_audio": "没有本地化音频",
    "no_localized_video": "没有本地化视频",
    "visual_content_required": "至少需要一个视觉内容",
    "visual_content_required_msg": "必须提供至少一个视觉内容（文本、图像、音频或视频）。"
  },
  "ja": {
    "renderer": "レンダラー",
    "visual_text": "ビジュアルテキスト",
    "no_images_added": "画像が追加されていません",
    "audio": "オーディオ",
    "no_localized_audio": "ローカライズされたオーディオはありません",
    "no_localized_video": "ローカライズされたビデオはありません",
    "visual_content_required": "少なくとも1つの視覚コンテンツが必要です",
    "visual_content_required_msg": "少なくとも1つの視覚コンテンツ（テキスト、画像、音声、またはビデオ）を提供する必要があります。"
  },
  "ko": {
    "renderer": "렌더러",
    "visual_text": "시각적 텍스트",
    "no_images_added": "추가된 이미지 없음",
    "audio": "오디오",
    "no_localized_audio": "현지화된 오디오 없음",
    "no_localized_video": "현지화된 비디오 없음",
    "visual_content_required": "하나 이상의 시각적 콘텐츠가 필요합니다",
    "visual_content_required_msg": "하나 이상의 시각적 콘텐츠(텍스트, 이미지, 오디오 또는 비디오)를 제공해야 합니다."
  }
}
"""

translations = json.loads(data_str)

sql_commands = []
for lang, keys in translations.items():
    for key, translation in keys.items():
        escaped_translation = translation.replace("'", "''")
        sql_commands.append(f"INSERT OR REPLACE INTO ui_translations (key, lang, value, updated_at) VALUES ('{key}', '{lang}', '{escaped_translation}', CURRENT_TIMESTAMP);")

full_sql = "\n".join(sql_commands)
with open("scripts/sql/update_add_card_ui.sql", "w") as f:
    f.write(full_sql)

print("SQL script generated at scripts/sql/update_add_card_ui.sql")
