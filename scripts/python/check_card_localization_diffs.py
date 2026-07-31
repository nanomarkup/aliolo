#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
import os
import shutil
import subprocess
import sys
import time
import unicodedata
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Protocol
from urllib import error as urllib_error
from urllib import request as urllib_request


ROOT = Path(__file__).resolve().parents[2]
API_DIR = ROOT / "api"
WRANGLER_BIN = API_DIR / "node_modules" / "wrangler" / "bin" / "wrangler.js"
DB_NAME = "aliolo-db"
DEFAULT_SKIP_FOLDER = "Languages"
DEFAULT_OUTPUT = ROOT / "scripts" / ".tmp" / "card_localization_report.csv"
DEFAULT_OPENAI_MODEL = "gpt-4o-mini"
DEFAULT_BATCH_SIZE = 20

FIELD_SPECS: tuple[tuple[str, str], ...] = (
    ("answer", "answers"),
    ("prompt", "prompts"),
    ("display_text", "display_texts"),
)


@dataclass(frozen=True)
class CardRecord:
    card_id: str
    subject_id: str
    subject_name: str
    folder_name: str
    answer: str
    answers: str
    prompt: str
    prompts: str
    display_text: str
    display_texts: str


@dataclass(frozen=True)
class LanguageRecord:
    code: str
    name: str


@dataclass(frozen=True)
class PendingCheck:
    card_id: str
    subject_id: str
    subject_name: str
    folder_name: str
    field: str
    locale: str
    base_value: str
    localized_value: str


@dataclass(frozen=True)
class DiffRow:
    card_id: str
    subject_id: str
    subject_name: str
    folder_name: str
    field: str
    locale: str
    base_value: str
    correct_locale_value: str
    localized_value: str
    diff_type: str


class TranslationProvider(Protocol):
    def translate_batch(self, locale_code: str, locale_name: str, texts: list[str]) -> dict[str, str]:
        ...


def resolve_node_bin() -> str:
    node_bin = shutil.which("node")
    if node_bin:
        return node_bin

    nvm_root = Path.home() / ".config" / "nvm" / "versions" / "node"
    if nvm_root.exists():
        for version_dir in sorted(nvm_root.iterdir(), reverse=True):
            candidate = version_dir / "bin" / "node"
            if candidate.exists():
                return str(candidate)

    raise RuntimeError("Node runtime not found. Install Node or add it to PATH before running this script.")


def wrangler_cmd() -> list[str]:
    return [resolve_node_bin(), str(WRANGLER_BIN)]


def shell_quote(value: str) -> str:
    return "'" + value.replace("'", "'\"'\"'") + "'"


def run_wrangler(args: list[str], *, json_output: bool = False) -> str | list[dict[str, Any]]:
    command = (
        "source /home/vitaliinoga/.config/nvm/nvm.sh "
        "&& nvm use --lts >/dev/null "
        "&& "
        + " ".join(shell_quote(arg) for arg in wrangler_cmd() + args)
    )
    result = subprocess.run(["bash", "-lc", command], cwd=API_DIR, capture_output=True, text=True)
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or f"exit code {result.returncode}"
        raise RuntimeError(detail)
    return json.loads(result.stdout) if json_output else result.stdout


def fetch_cards() -> list[CardRecord]:
    sql = """
      SELECT
        c.id AS card_id,
        c.subject_id,
        COALESCE(s.name, '') AS subject_name,
        COALESCE(f.name, '') AS folder_name,
        c.answer,
        c.answers,
        c.prompt,
        c.prompts,
        c.display_text,
        c.display_texts
      FROM cards c
      LEFT JOIN subjects s ON s.id = c.subject_id
      LEFT JOIN folders f ON f.id = s.folder_id
      ORDER BY c.subject_id, c.id
    """.strip()
    payload = run_wrangler(["d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"], json_output=True)
    rows = payload[0].get("results", []) if payload else []

    cards: list[CardRecord] = []
    for row in rows:
        cards.append(
            CardRecord(
                card_id=str(row.get("card_id") or ""),
                subject_id=str(row.get("subject_id") or ""),
                subject_name=str(row.get("subject_name") or ""),
                folder_name=str(row.get("folder_name") or ""),
                answer=str(row.get("answer") or ""),
                answers=str(row.get("answers") or ""),
                prompt=str(row.get("prompt") or ""),
                prompts=str(row.get("prompts") or ""),
                display_text=str(row.get("display_text") or ""),
                display_texts=str(row.get("display_texts") or ""),
            )
        )
    return cards


def fetch_languages() -> dict[str, LanguageRecord]:
    sql = """
      SELECT id, name
      FROM languages
      ORDER BY name
    """.strip()
    payload = run_wrangler(["d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"], json_output=True)
    rows = payload[0].get("results", []) if payload else []

    languages: dict[str, LanguageRecord] = {}
    for row in rows:
        code = str(row.get("id") or "").strip().lower()
        name = str(row.get("name") or "").strip()
        if code:
            languages[code] = LanguageRecord(code=code, name=name or code.upper())
    return languages


def parse_translation_map(raw: str) -> tuple[dict[str, str] | None, str | None]:
    if raw is None:
        return None, "missing_json"

    text = raw.strip()
    if not text:
        return None, "empty_json"

    try:
        parsed = json.loads(text)
    except json.JSONDecodeError:
        return None, "invalid_json"

    if not isinstance(parsed, dict):
        return None, "non_object_json"

    normalized: dict[str, str] = {}
    for key, value in parsed.items():
        if not isinstance(key, str) or not isinstance(value, str):
            return None, "non_string_translation"
        normalized[key] = value

    return normalized, None


def normalize_value(value: str) -> str:
    return unicodedata.normalize("NFC", value).strip()


class OpenAITranslationProvider:
    def __init__(self, api_key: str, model: str = DEFAULT_OPENAI_MODEL, base_url: str = "https://api.openai.com/v1") -> None:
        self.api_key = api_key.strip()
        self.model = model.strip() or DEFAULT_OPENAI_MODEL
        self.base_url = base_url.rstrip("/")

    def _request_json(self, path: str, payload: dict[str, Any]) -> dict[str, Any]:
        url = f"{self.base_url}{path}"
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        req = urllib_request.Request(
            url,
            data=body,
            method="POST",
            headers={
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
            },
        )

        last_error: Exception | None = None
        for attempt in range(4):
            try:
                with urllib_request.urlopen(req, timeout=120) as response:
                    response_body = response.read().decode("utf-8")
                    return json.loads(response_body)
            except urllib_error.HTTPError as exc:
                last_error = exc
                if exc.code not in {429, 500, 502, 503, 504} or attempt == 3:
                    detail = exc.read().decode("utf-8", errors="replace")
                    raise RuntimeError(detail or f"OpenAI request failed with HTTP {exc.code}") from exc
            except Exception as exc:  # noqa: BLE001
                last_error = exc
                if attempt == 3:
                    raise

            time.sleep(2**attempt)

        if last_error is not None:
            raise RuntimeError(str(last_error))
        raise RuntimeError("OpenAI request failed")

    def translate_batch(self, locale_code: str, locale_name: str, texts: list[str]) -> dict[str, str]:
        if not texts:
            return {}

        numbered_items = "\n".join(f"{index}: {text}" for index, text in enumerate(texts))
        system_prompt = (
            "You translate app card content from English into the requested target language. "
            "Return only valid JSON. Preserve meaning, numbers, placeholders, and punctuation. "
            "Do not explain anything."
        )
        user_prompt = (
            f"Translate the following English texts into {locale_name} ({locale_code}).\n"
            "Return a JSON object with a single key 'translations'. Its value must be an object mapping string indices to translated strings.\n"
            f"Texts:\n{numbered_items}"
        )
        payload = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            "temperature": 0,
            "response_format": {"type": "json_object"},
        }
        response = self._request_json("/chat/completions", payload)
        choices = response.get("choices", [])
        if not choices:
            raise RuntimeError("OpenAI response did not include any choices")
        message = choices[0].get("message", {})
        content = message.get("content")
        if not isinstance(content, str) or not content.strip():
            raise RuntimeError("OpenAI response did not include JSON content")

        parsed = json.loads(content)
        translations = parsed.get("translations")
        if not isinstance(translations, dict):
            raise RuntimeError("OpenAI response JSON did not include a translations object")

        result: dict[str, str] = {}
        for index, original in enumerate(texts):
            translated = translations.get(str(index))
            if not isinstance(translated, str):
                raise RuntimeError(f"OpenAI response missing translation for item {index}")
            result[original] = translated
        return result


def collect_translation_targets(
    cards: list[CardRecord],
    skip_folder_name: str,
) -> tuple[list[PendingCheck], list[DiffRow], dict[str, int], dict[str, list[str]]]:
    pending_checks: list[PendingCheck] = []
    immediate_diffs: list[DiffRow] = []
    requested_texts_by_locale: dict[str, list[str]] = {}
    summary = {"scanned": 0, "skipped": 0, "diffs": 0, "translation_pairs": 0}

    for card in cards:
        if card.folder_name == skip_folder_name:
            summary["skipped"] += 1
            continue

        summary["scanned"] += 1
        for base_field, localized_field in FIELD_SPECS:
            base_value = normalize_value(getattr(card, base_field))
            if not base_value:
                continue

            raw_localized = getattr(card, localized_field)
            translations, error = parse_translation_map(raw_localized)
            if error is not None or translations is None:
                immediate_diffs.append(
                    DiffRow(
                        card_id=card.card_id,
                        subject_id=card.subject_id,
                        subject_name=card.subject_name,
                        folder_name=card.folder_name,
                        field=base_field,
                        locale="",
                        base_value=getattr(card, base_field),
                        correct_locale_value="",
                        localized_value=raw_localized,
                        diff_type=error or "invalid_json",
                    )
                )
                continue

            for locale, localized_value in sorted(translations.items()):
                locale_code = locale.strip().lower()
                if not locale_code:
                    continue

                pending_checks.append(
                    PendingCheck(
                        card_id=card.card_id,
                        subject_id=card.subject_id,
                        subject_name=card.subject_name,
                        folder_name=card.folder_name,
                        field=base_field,
                        locale=locale_code,
                        base_value=getattr(card, base_field),
                        localized_value=localized_value,
                    )
                )

                locale_requests = requested_texts_by_locale.setdefault(locale_code, [])
                if base_value not in locale_requests:
                    locale_requests.append(base_value)

    summary["translation_pairs"] = sum(len(texts) for texts in requested_texts_by_locale.values())
    return pending_checks, immediate_diffs, summary, requested_texts_by_locale


def batched(values: list[str], batch_size: int) -> list[list[str]]:
    if batch_size <= 0:
        batch_size = DEFAULT_BATCH_SIZE
    return [values[index : index + batch_size] for index in range(0, len(values), batch_size)]


def resolve_expected_translations(
    requested_texts_by_locale: dict[str, list[str]],
    language_catalog: dict[str, LanguageRecord],
    provider: TranslationProvider,
    *,
    batch_size: int,
) -> tuple[dict[tuple[str, str], str], list[DiffRow]]:
    expected: dict[tuple[str, str], str] = {}
    errors: list[DiffRow] = []

    for locale_code, texts in requested_texts_by_locale.items():
        locale_info = language_catalog.get(locale_code)
        locale_name = locale_info.name if locale_info is not None else locale_code.upper()
        for batch in batched(texts, batch_size):
            try:
                translations = provider.translate_batch(locale_code, locale_name, batch)
            except Exception as exc:  # noqa: BLE001
                error_text = str(exc).strip() or "translation_error"
                for text in batch:
                    errors.append(
                        DiffRow(
                            card_id="",
                            subject_id="",
                            subject_name="",
                            folder_name="",
                            field="",
                            locale=locale_code,
                            base_value=text,
                            correct_locale_value="",
                            localized_value="",
                            diff_type=f"translation_error: {error_text}",
                        )
                    )
                continue

            for text in batch:
                translated = translations.get(text)
                if translated is None:
                    errors.append(
                        DiffRow(
                            card_id="",
                            subject_id="",
                            subject_name="",
                            folder_name="",
                            field="",
                            locale=locale_code,
                            base_value=text,
                            correct_locale_value="",
                            localized_value="",
                            diff_type="translation_missing",
                        )
                    )
                    continue
                expected[(locale_code, text)] = translated

    return expected, errors


def build_diff_rows(
    pending_checks: list[PendingCheck],
    expected_translations: dict[tuple[str, str], str],
) -> list[DiffRow]:
    diffs: list[DiffRow] = []
    for check in pending_checks:
        expected = expected_translations.get((check.locale, normalize_value(check.base_value)))
        if expected is None:
            diffs.append(
                DiffRow(
                    card_id=check.card_id,
                    subject_id=check.subject_id,
                    subject_name=check.subject_name,
                    folder_name=check.folder_name,
                    field=check.field,
                    locale=check.locale,
                    base_value=check.base_value,
                    correct_locale_value="",
                    localized_value=check.localized_value,
                    diff_type="translation_missing",
                )
            )
            continue

        if normalize_value(expected) != normalize_value(check.localized_value):
            diffs.append(
                DiffRow(
                    card_id=check.card_id,
                    subject_id=check.subject_id,
                    subject_name=check.subject_name,
                    folder_name=check.folder_name,
                    field=check.field,
                    locale=check.locale,
                    base_value=check.base_value,
                    correct_locale_value=expected,
                    localized_value=check.localized_value,
                    diff_type="mismatch",
                )
            )

    return diffs


def write_report(output_path: Path, diffs: list[DiffRow]) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "card_id",
                "subject_id",
                "subject_name",
                "folder_name",
                "field",
                "locale",
                "base_value",
                "correct_locale_value",
                "localized_value",
                "diff_type",
            ],
        )
        writer.writeheader()
        for diff in diffs:
            writer.writerow(
                {
                    "card_id": diff.card_id,
                    "subject_id": diff.subject_id,
                    "subject_name": diff.subject_name,
                    "folder_name": diff.folder_name,
                    "field": diff.field,
                    "locale": diff.locale,
                    "base_value": diff.base_value,
                    "correct_locale_value": diff.correct_locale_value,
                    "localized_value": diff.localized_value,
                    "diff_type": diff.diff_type,
                }
            )


def resolve_translation_provider(provider_name: str, openai_api_key: str | None, openai_model: str) -> TranslationProvider:
    if provider_name == "openai":
        if not openai_api_key or not openai_api_key.strip():
            raise RuntimeError("OPENAI_API_KEY is required to translate card content. Set it or pass --openai-api-key.")
        return OpenAITranslationProvider(openai_api_key, model=openai_model)

    raise RuntimeError(f"Unsupported translation provider: {provider_name}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Translate card base fields into each locale and compare them against the stored localized JSON maps."
    )
    parser.add_argument(
        "--output",
        default=str(DEFAULT_OUTPUT),
        help="Where to write the CSV report.",
    )
    parser.add_argument(
        "--skip-folder-name",
        default=DEFAULT_SKIP_FOLDER,
        help="Skip cards whose subject belongs to this folder name.",
    )
    parser.add_argument(
        "--provider",
        default="openai",
        choices=("openai",),
        help="Translation provider to use for expected locale values.",
    )
    parser.add_argument(
        "--openai-api-key",
        default=os.getenv("OPENAI_API_KEY"),
        help="OpenAI API key. Defaults to OPENAI_API_KEY.",
    )
    parser.add_argument(
        "--openai-model",
        default=os.getenv("OPENAI_MODEL", DEFAULT_OPENAI_MODEL),
        help="OpenAI model to use for translations.",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=DEFAULT_BATCH_SIZE,
        help="Maximum number of unique base texts to translate per API call.",
    )
    args = parser.parse_args()

    try:
        cards = fetch_cards()
        language_catalog = fetch_languages()
        pending_checks, immediate_diffs, summary, requested_texts_by_locale = collect_translation_targets(cards, args.skip_folder_name)
        provider = resolve_translation_provider(args.provider, args.openai_api_key, args.openai_model)
        expected_translations, translation_errors = resolve_expected_translations(
            requested_texts_by_locale,
            language_catalog,
            provider,
            batch_size=args.batch_size,
        )
        translated_diffs = build_diff_rows(pending_checks, expected_translations)
        diffs = [*immediate_diffs, *translation_errors, *translated_diffs]
        summary["diffs"] = len(diffs)
        output_path = Path(args.output).resolve()
        write_report(output_path, diffs)

        print(
            json.dumps(
                {
                    "output": str(output_path),
                    "scanned_cards": summary["scanned"],
                    "skipped_cards": summary["skipped"],
                    "translation_pairs": summary["translation_pairs"],
                    "diff_rows": summary["diffs"],
                },
                indent=2,
                ensure_ascii=False,
            )
        )
        return 0
    except Exception as exc:  # noqa: BLE001
        print(f"Card localization diff scan failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
