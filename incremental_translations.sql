BEGIN;

-- ar
INSERT INTO ui_translations (key, lang, value) VALUES
  ('learn_mode_title', 'ar', 'Learn'),
  ('test_mode_title', 'ar', 'Test'),
  ('no_cards_found_for_lang', 'ar', 'No cards found for this language')
ON CONFLICT (key, lang) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();

-- de
INSERT INTO ui_translations (key, lang, value) VALUES
  ('learn_mode_title', 'de', 'Learn'),
  ('test_mode_title', 'de', 'Test'),
  ('no_cards_found_for_lang', 'de', 'Keine Karten für diese Sprache gefunden')
ON CONFLICT (key, lang) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();

-- el
INSERT INTO ui_translations (key, lang, value) VALUES
  ('learn_mode_title', 'el', 'Learn'),
  ('test_mode_title', 'el', 'Test'),
  ('no_cards_found_for_lang', 'el', 'No cards found for this language')
ON CONFLICT (key, lang) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();

-- en
INSERT INTO ui_translations (key, lang, value) VALUES
  ('learn_mode_title', 'en', 'Learn'),
  ('test_mode_title', 'en', 'Test'),
  ('no_cards_found_for_lang', 'en', 'No cards found for this language')
ON CONFLICT (key, lang) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();

-- es
INSERT INTO ui_translations (key, lang, value) VALUES
  ('learn_mode_title', 'es', 'Learn'),
  ('test_mode_title', 'es', 'Test'),
  ('no_cards_found_for_lang', 'es', 'No se encontraron tarjetas para este idioma')
ON CONFLICT (key, lang) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();

-- fr
INSERT INTO ui_translations (key, lang, value) VALUES
  ('learn_mode_title', 'fr', 'Learn'),
  ('test_mode_title', 'fr', 'Test'),
  ('no_cards_found_for_lang', 'fr', 'Aucune carte trouvée pour cette langue')
ON CONFLICT (key, lang) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();

-- hi
INSERT INTO ui_translations (key, lang, value) VALUES
  ('learn_mode_title', 'hi', 'Learn'),
  ('test_mode_title', 'hi', 'Test'),
  ('no_cards_found_for_lang', 'hi', 'No cards found for this language')
ON CONFLICT (key, lang) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();

-- id
INSERT INTO ui_translations (key, lang, value) VALUES
  ('learn_mode_title', 'id', 'Learn'),
  ('test_mode_title', 'id', 'Test'),
  ('no_cards_found_for_lang', 'id', 'No cards found for this language')
ON CONFLICT (key, lang) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();

-- it
INSERT INTO ui_translations (key, lang, value) VALUES
  ('learn_mode_title', 'it', 'Learn'),
  ('test_mode_title', 'it', 'Test'),
  ('no_cards_found_for_lang', 'it', 'Nessuna carta trovata per questa lingua')
ON CONFLICT (key, lang) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();

-- ja
INSERT INTO ui_translations (key, lang, value) VALUES
  ('learn_mode_title', 'ja', 'Learn'),
  ('test_mode_title', 'ja', 'Test'),
  ('no_cards_found_for_lang', 'ja', 'この言語のカードは見つかりませんでした')
ON CONFLICT (key, lang) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();

-- ko
INSERT INTO ui_translations (key, lang, value) VALUES
  ('learn_mode_title', 'ko', 'Learn'),
  ('test_mode_title', 'ko', 'Test'),
  ('no_cards_found_for_lang', 'ko', '이 언어의 카드를 찾을 수 없습니다')
ON CONFLICT (key, lang) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();

-- nl
INSERT INTO ui_translations (key, lang, value) VALUES
  ('learn_mode_title', 'nl', 'Learn'),
  ('test_mode_title', 'nl', 'Test'),
  ('no_cards_found_for_lang', 'nl', 'No cards found for this language')
ON CONFLICT (key, lang) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();

-- pl
INSERT INTO ui_translations (key, lang, value) VALUES
  ('learn_mode_title', 'pl', 'Learn'),
  ('test_mode_title', 'pl', 'Test'),
  ('no_cards_found_for_lang', 'pl', 'Brak kart dla tego języka')
ON CONFLICT (key, lang) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();

-- pt
INSERT INTO ui_translations (key, lang, value) VALUES
  ('learn_mode_title', 'pt', 'Learn'),
  ('test_mode_title', 'pt', 'Test'),
  ('no_cards_found_for_lang', 'pt', 'Nenhuma carta encontrada para este idioma')
ON CONFLICT (key, lang) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();

-- tl
INSERT INTO ui_translations (key, lang, value) VALUES
  ('learn_mode_title', 'tl', 'Learn'),
  ('test_mode_title', 'tl', 'Test'),
  ('no_cards_found_for_lang', 'tl', 'No cards found for this language')
ON CONFLICT (key, lang) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();

-- tr
INSERT INTO ui_translations (key, lang, value) VALUES
  ('learn_mode_title', 'tr', 'Learn'),
  ('test_mode_title', 'tr', 'Test'),
  ('no_cards_found_for_lang', 'tr', 'No cards found for this language')
ON CONFLICT (key, lang) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();

-- uk
INSERT INTO ui_translations (key, lang, value) VALUES
  ('learn_mode_title', 'uk', 'Вивчити'),
  ('test_mode_title', 'uk', 'Тест'),
  ('no_cards_found_for_lang', 'uk', 'Для цієї мови карток не знайдено')
ON CONFLICT (key, lang) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();

-- vi
INSERT INTO ui_translations (key, lang, value) VALUES
  ('learn_mode_title', 'vi', 'Learn'),
  ('test_mode_title', 'vi', 'Test'),
  ('no_cards_found_for_lang', 'vi', 'No cards found for this language')
ON CONFLICT (key, lang) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();

-- zh
INSERT INTO ui_translations (key, lang, value) VALUES
  ('learn_mode_title', 'zh', 'Learn'),
  ('test_mode_title', 'zh', 'Test'),
  ('no_cards_found_for_lang', 'zh', '找不到该语言的卡片')
ON CONFLICT (key, lang) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();

COMMIT;
