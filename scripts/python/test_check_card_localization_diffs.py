from __future__ import annotations

import sys
import unittest
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from check_card_localization_diffs import (  # noqa: E402
    CardRecord,
    LanguageRecord,
    build_diff_rows,
    collect_translation_targets,
    parse_translation_map,
    resolve_expected_translations,
)


class FakeTranslationProvider:
    def __init__(self, translations: dict[tuple[str, str], str]) -> None:
        self.translations = translations
        self.calls: list[tuple[str, str, tuple[str, ...]]] = []

    def translate_batch(self, locale_code: str, locale_name: str, texts: list[str]) -> dict[str, str]:
        self.calls.append((locale_code, locale_name, tuple(texts)))
        return {
            text: self.translations[(locale_code, text)]
            for text in texts
            if (locale_code, text) in self.translations
        }


class CardLocalizationDiffTests(unittest.TestCase):
    def test_translation_match_is_skipped(self) -> None:
        card = CardRecord(
            card_id="card_1",
            subject_id="subject_1",
            subject_name="Sports",
            folder_name="",
            answer="Circle",
            answers='{"es":"Círculo"}',
            prompt="What is this?",
            prompts="{}",
            display_text="1 + 3",
            display_texts="{}",
        )
        language_catalog = {"es": LanguageRecord(code="es", name="Spanish")}
        provider = FakeTranslationProvider({("es", "Circle"): "Círculo"})

        pending_checks, immediate_diffs, summary, requested_texts_by_locale = collect_translation_targets([card], "Languages")
        expected, translation_errors = resolve_expected_translations(
            requested_texts_by_locale,
            language_catalog,
            provider,
            batch_size=10,
        )
        diffs = [*immediate_diffs, *translation_errors, *build_diff_rows(pending_checks, expected)]

        self.assertEqual(summary["scanned"], 1)
        self.assertEqual(summary["skipped"], 0)
        self.assertEqual(summary["translation_pairs"], 1)
        self.assertEqual(provider.calls, [("es", "Spanish", ("Circle",))])
        self.assertEqual(diffs, [])

    def test_translation_mismatch_is_reported(self) -> None:
        card = CardRecord(
            card_id="card_1",
            subject_id="subject_1",
            subject_name="Sports",
            folder_name="",
            answer="Circle",
            answers='{"es":"Circulo"}',
            prompt="What is this?",
            prompts="{}",
            display_text="1 + 3",
            display_texts="{}",
        )
        language_catalog = {"es": LanguageRecord(code="es", name="Spanish")}
        provider = FakeTranslationProvider({("es", "Circle"): "Círculo"})

        pending_checks, immediate_diffs, _, requested_texts_by_locale = collect_translation_targets([card], "Languages")
        expected, translation_errors = resolve_expected_translations(
            requested_texts_by_locale,
            language_catalog,
            provider,
            batch_size=10,
        )
        diffs = [*immediate_diffs, *translation_errors, *build_diff_rows(pending_checks, expected)]

        self.assertEqual(len(diffs), 1)
        self.assertEqual(diffs[0].diff_type, "mismatch")
        self.assertEqual(diffs[0].correct_locale_value, "Círculo")
        self.assertEqual(diffs[0].localized_value, "Circulo")

    def test_empty_base_value_skips_translation(self) -> None:
        card = CardRecord(
            card_id="card_1",
            subject_id="subject_1",
            subject_name="Sports",
            folder_name="",
            answer="",
            answers='{"es":"Hola"}',
            prompt="",
            prompts='{"es":"¿Qué es esto?"}',
            display_text="",
            display_texts='{"es":"Texto"}',
        )

        pending_checks, immediate_diffs, summary, requested_texts_by_locale = collect_translation_targets([card], "Languages")

        self.assertEqual(pending_checks, [])
        self.assertEqual(immediate_diffs, [])
        self.assertEqual(summary["translation_pairs"], 0)
        self.assertEqual(requested_texts_by_locale, {})

    def test_invalid_json_is_reported_immediately(self) -> None:
        card = CardRecord(
            card_id="card_1",
            subject_id="subject_1",
            subject_name="Sports",
            folder_name="",
            answer="Hello",
            answers='{"es": 1}',
            prompt="What is this?",
            prompts="{}",
            display_text="1 + 3",
            display_texts="{}",
        )

        pending_checks, immediate_diffs, _, _ = collect_translation_targets([card], "Languages")
        self.assertEqual(pending_checks, [])
        self.assertEqual(len(immediate_diffs), 1)
        self.assertEqual(immediate_diffs[0].diff_type, "non_string_translation")

    def test_skip_languages_folder(self) -> None:
        cards = [
            CardRecord(
                card_id="card_1",
                subject_id="subject_1",
                subject_name="English",
                folder_name="Languages",
                answer="Hello",
                answers='{"es":"Hola"}',
                prompt="What is this?",
                prompts='{"es":"¿Qué es esto?"}',
                display_text="1 + 3",
                display_texts='{"es":"1 + 3"}',
            ),
            CardRecord(
                card_id="card_2",
                subject_id="subject_2",
                subject_name="Sports",
                folder_name="",
                answer="World",
                answers='{"es":"Mundo"}',
                prompt="What is that?",
                prompts="{}",
                display_text="2 + 2",
                display_texts="{}",
            ),
        ]

        pending_checks, immediate_diffs, summary, requested_texts_by_locale = collect_translation_targets(cards, "Languages")
        self.assertEqual(summary["skipped"], 1)
        self.assertEqual(summary["scanned"], 1)
        self.assertEqual(summary["translation_pairs"], 1)
        self.assertEqual(len(pending_checks), 1)
        self.assertEqual(immediate_diffs, [])
        self.assertEqual(requested_texts_by_locale, {"es": ["World"]})

    def test_parse_translation_map(self) -> None:
        translations, error = parse_translation_map('{"en":"Hello","es":"Hola"}')
        self.assertIsNone(error)
        self.assertEqual(translations, {"en": "Hello", "es": "Hola"})


if __name__ == "__main__":
    unittest.main()
