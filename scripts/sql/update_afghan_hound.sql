UPDATE cards
SET localized_data = '{
  "global": {
    "answer": "Afghan Hound",
    "video_url": "",
    "image_urls": [
      "https://mltdjjszycfmokwqsqxm.supabase.co/storage/v1/object/public/card_images/f2fb4c9c-169b-447d-b8a6-dce72c4ed5ac/Dogs/f92944a9-9432-482a-b112-75b3037b4e29.jpg"
    ]
  },
  "ar": {
    "answer": "الكلب السلوقي الأفغاني"
  },
  "bg": {
    "answer": "Афганска хрътка"
  },
  "cs": {
    "answer": "Afghan Hound"
  },
  "da": {
    "answer": "Afghan Hound"
  },
  "de": {
    "answer": "Afghan Hound"
  },
  "el": {
    "answer": "Αφγανικό Λαγωνικό"
  },
  "en": {
    "answer": "Afghan Hound"
  },
  "es": {
    "answer": "Afghan Hound"
  },
  "et": {
    "answer": "Afghan Hound"
  },
  "fi": {
    "answer": "Afghan Hound"
  },
  "fr": {
    "answer": "Afghan Hound"
  },
  "ga": {
    "answer": "Afghan Hound"
  },
  "hi": {
    "answer": "अफ़गान हाउंड"
  },
  "hr": {
    "answer": "Afghan Hound"
  },
  "hu": {
    "answer": "Afghan Hound"
  },
  "id": {
    "answer": "Afghan Hound"
  },
  "it": {
    "answer": "Afghan Hound"
  },
  "ja": {
    "answer": "アフガン・ハウンド"
  },
  "ko": {
    "answer": "아프간하운드"
  },
  "lt": {
    "answer": "Afghan Hound"
  },
  "lv": {
    "answer": "Afghan Hound"
  },
  "mt": {
    "answer": "Afghan Hound"
  },
  "nl": {
    "answer": "Afghan Hound"
  },
  "pl": {
    "answer": "Afghan Hound"
  },
  "pt": {
    "answer": "Afghan Hound"
  },
  "ro": {
    "answer": "Afghan Hound"
  },
  "sk": {
    "answer": "Afghan Hound"
  },
  "sl": {
    "answer": "Afghan Hound"
  },
  "sv": {
    "answer": "Afghan Hound"
  },
  "tl": {
    "answer": "Afghan Hound"
  },
  "tr": {
    "answer": "Afghan Hound"
  },
  "uk": {
    "answer": "Афганський хорт"
  },
  "vi": {
    "answer": "Chó săn Afghanistan"
  },
  "zh": {
    "answer": "阿富汗猎犬"
  }
}'::jsonb
FROM subjects
WHERE cards.subject_id = subjects.id
  AND subjects.localized_data->'global'->>'name' = 'Dog Breeds'
  AND cards.localized_data->'global'->>'answer' = 'Afghan Hound';
