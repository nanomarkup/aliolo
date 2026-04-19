#!/usr/bin/env python3
from __future__ import annotations

import argparse
import concurrent.futures as futures
import json
import re
import sys
import time
import urllib.parse
import urllib.request
import urllib.error
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable

import yaml


SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
DEFAULT_INVENTORY_PATH = SCRIPT_DIR / "ui_text_variables.yaml"
DEFAULT_SQL_PATH = SCRIPT_DIR / "sql" / "generated_ui_translations.sql"

SUPPORTED_LANGUAGES = [
    "en",
    "id",
    "bg",
    "cs",
    "da",
    "de",
    "et",
    "es",
    "fr",
    "ga",
    "hr",
    "it",
    "lv",
    "lt",
    "hu",
    "mt",
    "nl",
    "pl",
    "pt",
    "ro",
    "sk",
    "sl",
    "fi",
    "sv",
    "tl",
    "vi",
    "tr",
    "el",
    "uk",
    "ar",
    "hi",
    "zh",
    "ja",
    "ko",
]

PAGE_SEED_SQL_DIR = SCRIPT_DIR / "sql"
SQL_INSERT_BATCH_SIZE = 100

EXPLICIT_TRANSLATION_KEYS = {
    "about": "About",
    "all_rights_reserved": "All rights reserved",
    "back": "Back",
    "documentation": "Documentation",
    "home": "Home",
    "leaderboard": "Leaderboard",
    "licenses": "Licenses",
    "profile": "Profile",
    "settings": "Settings",
    "version": "Version",
    "view_onboarding": "View onboarding",
    "show_documentation_btn": "Show documentation button",
    "show_documentation_btn_desc": "Display the documentation button in the app bar.",
}

DO_NOT_TRANSLATE = {
    "aliolo",
    "Aliolo",
}

SNAKE_CASE_RE = re.compile(r"^[a-z0-9_]+$")
ALPHA_RE = re.compile(r"[A-Za-z]")
PLACEHOLDER_RE = re.compile(r"(\$\{[^}]+\}|\$[A-Za-z_][A-Za-z0-9_]*|\{[A-Za-z0-9_.:-]+\})")


@dataclass
class SourceLocation:
    file: str
    line: int
    kind: str


@dataclass
class InventoryEntry:
    key: str
    english: str
    translate: bool = True
    notes: list[str] = field(default_factory=list)
    sources: list[SourceLocation] = field(default_factory=list)


def slugify(text: str) -> str:
    text = text.strip()
    if text in {"$label:", "$label: ", "${label}:", "${label}: "}:
        return "label_suffix"
    text = re.sub(r"\$\{[^}]+\}", " ", text)
    text = re.sub(r"\$[A-Za-z_][A-Za-z0-9_]*", " ", text)
    text = text.replace("&", " and ")
    text = re.sub(r"[^A-Za-z0-9]+", "_", text)
    text = re.sub(r"_+", "_", text).strip("_").lower()
    if not text:
        text = "ui_text"
    if text[0].isdigit():
        text = f"ui_{text}"
    return text


def escape_sql(value: str) -> str:
    return value.replace("'", "''")


def load_yaml(path: Path) -> dict:
    if not path.exists():
        return {"version": 1, "entries": []}
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not data:
        return {"version": 1, "entries": []}
    if "entries" not in data:
        data["entries"] = []
    if "version" not in data:
        data["version"] = 1
    return data


def dump_yaml(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as fh:
        yaml.safe_dump(data, fh, sort_keys=False, allow_unicode=True, width=120)


def should_keep(text: str) -> bool:
    stripped = text.strip()
    if not stripped:
        return False
    if not ALPHA_RE.search(stripped):
        return False
    if re.fullmatch(r"\$[A-Za-z_][A-Za-z0-9_]*", stripped):
        return False
    if stripped in DO_NOT_TRANSLATE:
        return True
    if SNAKE_CASE_RE.fullmatch(stripped):
        return False
    if stripped in {"?", "??", "???", "_", "-", "+", "•"}:
        return False
    if re.fullmatch(r"[0-9./()%\s]+", stripped):
        return False
    return True


def add_candidate(
    entries: dict[str, InventoryEntry],
    english: str,
    source_file: str,
    line: int,
    kind: str,
    key_override: str | None = None,
    notes: Iterable[str] = (),
) -> None:
    english = english.strip()
    noise_fragments = (
        "context.t(",
        "context.plural(",
        "f.metadata[",
        "widget.feedback.metadata[",
        "${context.",
        "${f.",
        "${widget.",
        "user.totalXp",
        "user.nextDailyGoal",
        "user.learnSessionSize",
        "user.testSessionSize",
        "user.optionsCount",
        "seconds}",
        ")}",
        "rank + 1",
        "index + 1",
        "filteredUsers.length",
    )
    if any(fragment in english for fragment in noise_fragments):
        return
    if not should_keep(english):
        return

    key = key_override or slugify(english)
    entry = entries.get(key)
    if entry is None:
        translate = english not in DO_NOT_TRANSLATE
        if key == "label_suffix":
            translate = False
        entry = InventoryEntry(key=key, english=english, translate=translate)
        entries[key] = entry
    # Preserve the first-seen form as canonical English source text.
    for note in notes:
        if note and note not in entry.notes:
            entry.notes.append(note)
    location = SourceLocation(file=source_file, line=line, kind=kind)
    if location not in entry.sources:
        entry.sources.append(location)


TEXT_WIDGET_RE = re.compile(
    r"(?:const\s+)?Text\s*\(\s*(?P<q>['\"])(?P<text>.*?)(?P=q)",
    re.S,
)

SELECTABLE_TEXT_RE = re.compile(
    r"(?:const\s+)?SelectableText\s*\(\s*(?P<q>['\"])(?P<text>.*?)(?P=q)",
    re.S,
)

PROP_RE = re.compile(
    r"(?:tooltip|message|labelText|hintText|helperText|semanticLabel|barrierLabel)\s*:\s*(?:const\s+)?(?P<q>['\"])(?P<text>.*?)(?P=q)",
    re.S,
)

DETAIL_ROW_RE = re.compile(
    r"_buildDetailRow\s*\(\s*[^,]+,\s*(?P<q>['\"])(?P<text>.*?)(?P=q)",
    re.S,
)

HELPER_CALL_HINTS = (
    "_showMsg(",
    "_showError(",
    "showMsg(",
    "showError(",
    "showSnackBar(",
    "SnackBar(",
)


def line_has_visible_helper(line: str) -> bool:
    return any(hint in line for hint in HELPER_CALL_HINTS)


def extract_strings_from_line(line: str) -> list[str]:
    values = []
    for text in re.findall(r"['\"]([^'\"]+)['\"]", line):
        stripped = text.strip()
        if not stripped:
            continue
        if SNAKE_CASE_RE.fullmatch(stripped):
            continue
        if stripped.startswith("${context.") or stripped.startswith("${f.") or stripped.startswith("${widget."):
            continue
        if "context.t(" in stripped or "context.plural(" in stripped:
            continue
        if "f.metadata[" in stripped or "widget.feedback.metadata[" in stripped:
            continue
        if stripped.startswith("package:") or stripped.startswith("http://") or stripped.startswith("https://"):
            continue
        if "[" in stripped or "]" in stripped:
            # Usually a partial capture from an interpolated expression.
            continue
        values.append(stripped)
    return values


def scan_file(path: Path) -> list[tuple[str, int, str, list[str]]]:
    text = path.read_text(encoding="utf-8")
    candidates: list[tuple[str, int, str, list[str]]] = []

    for regex, kind in (
        (TEXT_WIDGET_RE, "Text"),
        (SELECTABLE_TEXT_RE, "SelectableText"),
        (PROP_RE, "prop"),
        (DETAIL_ROW_RE, "detail_row"),
    ):
        for match in regex.finditer(text):
            english = match.group("text")
            line = text.count("\n", 0, match.start()) + 1
            candidates.append((english, line, kind, []))

    for idx, line in enumerate(text.splitlines(), 1):
        if line_has_visible_helper(line) or "String title" in line or "String sub" in line or "title =" in line or "sub =" in line:
            for english in extract_strings_from_line(line):
                candidates.append((english, idx, "helper", []))
        if "'Context:" in line or '"Context:' in line:
            candidates.append(("Context", idx, "manual", []))
        if "'UA:" in line or '"UA:' in line:
            candidates.append(("UA", idx, "manual", []))

    return candidates


SQL_ROW_RE = re.compile(
    r"^\s*\('(?P<key>(?:[^']|'{2})+)'\s*,\s*'(?P<lang>[^']+)'\s*,\s*'(?P<value>(?:[^']|'{2})*)'\s*,\s*CURRENT_TIMESTAMP\),?\s*$"
)


def scan_sql_seed_file(path: Path) -> list[tuple[str, int, str, list[str]]]:
    candidates: list[tuple[str, int, str, list[str], str | None]] = []
    for idx, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        match = SQL_ROW_RE.match(line)
        if not match:
            continue
        key = match.group("key").replace("''", "'")
        value = match.group("value").replace("''", "'")
        candidates.append((value, idx, "sql_seed", [f"key={key}"], key))
    return candidates


def load_existing_sql_translations(path: Path) -> dict[str, dict[str, str]]:
    if not path.exists():
        return {}

    translations: dict[str, dict[str, str]] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        match = SQL_ROW_RE.match(line)
        if not match:
            continue
        key = match.group("key").replace("''", "'")
        lang = match.group("lang")
        value = match.group("value").replace("''", "'")
        translations.setdefault(key, {})[lang] = value
    return translations


def scan_inventory(root: Path) -> dict:
    entries: dict[str, InventoryEntry] = {}
    for path in sorted(root.rglob("*.dart")):
        if "test" in path.parts or "generated" in path.name:
            continue
        rel = path.relative_to(REPO_ROOT).as_posix()
        for english, line, kind, notes in scan_file(path):
            add_candidate(entries, english, rel, line, kind, None, notes)

    for path in sorted(PAGE_SEED_SQL_DIR.glob("add_*_translations.sql")):
        rel = path.relative_to(REPO_ROOT).as_posix()
        for english, line, kind, notes, key_override in scan_sql_seed_file(path):
            add_candidate(entries, english, rel, line, kind, key_override, notes)

    for key, english in EXPLICIT_TRANSLATION_KEYS.items():
        add_candidate(entries, english, "scripts/generate_ui_translations.py", 0, "explicit", key_override=key)

    items = []
    for key in sorted(entries):
        entry = entries[key]
        items.append(
            {
                "key": entry.key,
                "english": entry.english,
                "translate": entry.translate,
                "notes": entry.notes,
                "sources": [
                    {"file": s.file, "line": s.line, "kind": s.kind}
                    for s in sorted(entry.sources, key=lambda x: (x.file, x.line, x.kind))
                ],
            }
        )
    return {"version": 1, "entries": items}


def protect_terms(text: str) -> tuple[str, dict[str, str]]:
    replacements: dict[str, str] = {}

    def replace(match: re.Match[str]) -> str:
        token = f"__ALI_PROTECT_{len(replacements)}__"
        replacements[token] = match.group(0)
        return token

    protected = PLACEHOLDER_RE.sub(replace, text)
    for term in sorted(DO_NOT_TRANSLATE, key=len, reverse=True):
        if term in protected:
            token = f"__ALI_TERM_{len(replacements)}__"
            replacements[token] = term
            protected = protected.replace(term, token)
    return protected, replacements


def restore_terms(text: str, replacements: dict[str, str]) -> str:
    for token, original in replacements.items():
        text = text.replace(token, original)
    return text


def align_leading_case(source: str, translated: str) -> str:
    source_text = source.lstrip()
    translated_text = translated.lstrip()
    if not source_text or not translated_text:
        return translated

    if not source_text[0].isupper():
        return translated

    first_char = translated_text[0]
    if not first_char.isalpha() or first_char.isupper():
        return translated

    aligned = first_char.upper() + translated_text[1:]
    prefix_len = len(translated) - len(translated_text)
    return translated[:prefix_len] + aligned


def translate_google(text: str, target_lang: str) -> str:
    protected, replacements = protect_terms(text)
    params = {
        "client": "gtx",
        "sl": "en",
        "tl": target_lang,
        "dt": "t",
        "q": protected,
    }
    url = "https://translate.googleapis.com/translate_a/single?" + urllib.parse.urlencode(params)
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Mozilla/5.0",
            "Accept": "application/json",
        },
    )
    last_error: Exception | None = None
    for attempt in range(4):
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                payload = json.loads(response.read().decode("utf-8"))
            translated = "".join(part[0] for part in payload[0] if part and part[0])
            return align_leading_case(text, restore_terms(translated, replacements))
        except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
            last_error = exc
            if attempt < 3:
                time.sleep(0.5 * (attempt + 1))
                continue
            raise exc
    raise RuntimeError(last_error or "translation failed")


def generate_translations(
    entries: list[dict],
    provider: str = "google",
    existing_translations: dict[str, dict[str, str]] | None = None,
) -> dict[str, dict[str, str]]:
    cache: dict[tuple[str, str], str] = {}
    existing_translations = existing_translations or {}

    def translate_one(text: str, lang: str) -> str:
        if lang == "en":
            return text
        key = (text, lang)
        if key in cache:
            return cache[key]
        if provider == "google":
            translated = translate_google(text, lang)
        elif provider == "none":
            translated = text
        else:
            raise ValueError(f"Unsupported provider: {provider}")
        translated = align_leading_case(text, translated)
        cache[key] = translated
        return translated

    result: dict[str, dict[str, str]] = {}
    tasks: list[tuple[str, str]] = []
    for entry in entries:
        english = entry["english"]
        key = entry["key"]
        existing_for_key = existing_translations.get(key, {})
        if not entry.get("translate", True):
            result[key] = {
                lang: align_leading_case(english, existing_for_key.get(lang, english))
                for lang in SUPPORTED_LANGUAGES
            }
            continue
        result[key] = {"en": existing_for_key.get("en", english)}
        for lang in SUPPORTED_LANGUAGES:
            if lang == "en":
                continue
            if lang in existing_for_key and existing_for_key[lang].strip():
                result[key][lang] = align_leading_case(english, existing_for_key[lang])
                continue
            tasks.append((key, lang))

    with futures.ThreadPoolExecutor(max_workers=4) as executor:
        future_map = {}
        for key, lang in tasks:
            english = next(item["english"] for item in entries if item["key"] == key)
            future = executor.submit(translate_one, english, lang)
            future_map[future] = (key, lang)

        for future in futures.as_completed(future_map):
            key, lang = future_map[future]
            try:
                result[key][lang] = align_leading_case(english, future.result())
            except Exception as exc:  # noqa: BLE001
                print(f"Warning: translation failed for {key}/{lang}: {exc}", file=sys.stderr)
                result[key][lang] = result[key]["en"]

    return result


def render_sql(entries: list[dict], translations: dict[str, dict[str, str]]) -> str:
    lines: list[str] = []
    tuples: list[str] = []
    for entry in entries:
        key = entry["key"]
        for lang in SUPPORTED_LANGUAGES:
            value = translations[key][lang]
            tuples.append(
                f"  ('{escape_sql(key)}', '{lang}', '{escape_sql(value)}', CURRENT_TIMESTAMP)"
            )
    for start in range(0, len(tuples), SQL_INSERT_BATCH_SIZE):
        batch = tuples[start : start + SQL_INSERT_BATCH_SIZE]
        lines.append("INSERT INTO ui_translations (key, lang, value, updated_at) VALUES")
        lines.append(",\n".join(batch))
        lines.append("ON CONFLICT(key, lang) DO UPDATE SET")
        lines.append("  value = excluded.value,")
        lines.append("  updated_at = CURRENT_TIMESTAMP;")
        if start + SQL_INSERT_BATCH_SIZE < len(tuples):
            lines.append("")
    return "\n".join(lines) + "\n"


def write_inventory(path: Path, data: dict) -> None:
    dump_yaml(path, data)


def load_inventory_entries(path: Path) -> list[dict]:
    data = load_yaml(path)
    entries = data.get("entries", [])
    if not isinstance(entries, list):
        raise ValueError(f"Invalid inventory format in {path}")
    return entries


def cmd_scan(args: argparse.Namespace) -> None:
    inventory = scan_inventory(Path(args.root))
    write_inventory(Path(args.inventory), inventory)
    print(f"Wrote {len(inventory['entries'])} entries to {args.inventory}")


def cmd_sql(args: argparse.Namespace) -> None:
    inventory_path = Path(args.inventory)
    output_path = Path(args.output)
    entries = load_inventory_entries(inventory_path)
    if args.only_translatable:
        entries = [entry for entry in entries if entry.get("translate", True)]
    if not entries:
        raise SystemExit("No entries found in inventory")

    existing_translations = load_existing_sql_translations(output_path)
    translations = generate_translations(
        entries,
        provider=args.provider,
        existing_translations=existing_translations,
    )
    sql = render_sql(entries, translations)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(sql, encoding="utf-8")
    print(f"Wrote SQL for {len(entries)} keys to {output_path}")


def cmd_refresh(args: argparse.Namespace) -> None:
    inventory = scan_inventory(Path(args.root))
    write_inventory(Path(args.inventory), inventory)
    entries = inventory["entries"]
    if args.only_translatable:
        entries = [entry for entry in entries if entry.get("translate", True)]
    output_path = Path(args.output)
    existing_translations = load_existing_sql_translations(output_path)
    translations = generate_translations(
        entries,
        provider=args.provider,
        existing_translations=existing_translations,
    )
    sql = render_sql(entries, translations)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(sql, encoding="utf-8")
    print(f"Wrote inventory and SQL to {args.inventory} and {args.output}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Scan Dart UI strings and generate translation SQL.")
    parser.add_argument(
        "--root",
        default=str(REPO_ROOT / "lib"),
        help="Root directory to scan for Dart source files.",
    )
    parser.add_argument(
        "--inventory",
        default=str(DEFAULT_INVENTORY_PATH),
        help="Path to the YAML inventory file.",
    )
    parser.add_argument(
        "--output",
        default=str(DEFAULT_SQL_PATH),
        help="Path to the generated SQL file.",
    )
    parser.add_argument(
        "--provider",
        default="google",
        choices=["google", "none"],
        help="Machine translation provider to use when generating SQL.",
    )
    parser.add_argument(
        "--only-translatable",
        action="store_true",
        help="Skip inventory entries explicitly marked as non-translatable.",
    )

    subparsers = parser.add_subparsers(dest="command")

    scan_parser = subparsers.add_parser("scan", help="Scan Dart files and update the YAML inventory.")
    scan_parser.set_defaults(func=cmd_scan)

    sql_parser = subparsers.add_parser("sql", help="Generate SQL from an existing YAML inventory.")
    sql_parser.set_defaults(func=cmd_sql)

    refresh_parser = subparsers.add_parser("refresh", help="Scan Dart files and generate SQL in one pass.")
    refresh_parser.set_defaults(func=cmd_refresh)

    parser.set_defaults(func=cmd_refresh, command="refresh")
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        args.func(args)
    except Exception as exc:  # noqa: BLE001
        print(f"Error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
