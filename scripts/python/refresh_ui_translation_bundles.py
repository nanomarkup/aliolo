#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
API_DIR = ROOT / "api"
WRANGLER_BIN = API_DIR / "node_modules" / "wrangler" / "bin" / "wrangler.js"
DB_NAME = "aliolo-db"


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


def sql_literal(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def run_wrangler(args: list[str], *, json_output: bool = False) -> str | list[dict]:
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


def ensure_bundle_table() -> None:
    sql = """
      CREATE TABLE IF NOT EXISTS ui_translation_bundles (
        lang TEXT PRIMARY KEY,
        translations TEXT NOT NULL,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    """.strip()
    run_wrangler(["d1", "execute", DB_NAME, "--command", sql, "--remote"])


def fetch_languages() -> list[str]:
    sql = "SELECT DISTINCT lang FROM ui_translations ORDER BY lang"
    payload = run_wrangler(["d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"], json_output=True)
    if not payload or not payload[0].get("results"):
        return []

    langs: list[str] = []
    for row in payload[0]["results"]:
        lang = row.get("lang")
        if isinstance(lang, str) and lang.strip():
            langs.append(lang.lower())
    return langs


def fetch_translation_map(lang: str) -> dict[str, str]:
    sql = f"SELECT key, value FROM ui_translations WHERE lang = {sql_literal(lang)} ORDER BY key"
    payload = run_wrangler(["d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"], json_output=True)

    translations: dict[str, str] = {}
    rows = payload[0].get("results", []) if payload else []
    for row in rows:
        key = row.get("key")
        value = row.get("value")
        if isinstance(key, str) and isinstance(value, str):
            translations[key] = value
    return translations


def upsert_bundle(lang: str, translations: dict[str, str]) -> None:
    payload = json.dumps(translations, ensure_ascii=False, separators=(",", ":"))
    sql = """
      INSERT INTO ui_translation_bundles (lang, translations, updated_at)
      VALUES (?, ?, CURRENT_TIMESTAMP)
      ON CONFLICT(lang) DO UPDATE SET
        translations = excluded.translations,
        updated_at = CURRENT_TIMESTAMP
    """.strip()
    run_wrangler(
        ["d1", "execute", DB_NAME, "--command", sql, "--remote", "--params", lang, payload],
        json_output=False,
    )


def refresh_bundles(langs: list[str], *, dry_run: bool = False) -> dict[str, int]:
    refreshed = 0
    empty = 0

    for lang in langs:
        translations = fetch_translation_map(lang)
        if not translations:
            empty += 1
        if dry_run:
            print(
                json.dumps(
                    {
                        "lang": lang,
                        "translation_count": len(translations),
                        "dry_run": True,
                    },
                    ensure_ascii=False,
                )
            )
            continue
        upsert_bundle(lang, translations)
        refreshed += 1

    return {"refreshed": refreshed, "empty": empty}


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Rebuild ui_translation_bundles from ui_translations in remote D1."
    )
    parser.add_argument(
        "--lang",
        action="append",
        dest="langs",
        help="Refresh only the given language code. Can be repeated.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be refreshed without writing bundle rows.",
    )
    args = parser.parse_args()

    try:
        ensure_bundle_table()
        langs = [lang.lower() for lang in args.langs] if args.langs else fetch_languages()
        if not langs:
            print(
                json.dumps(
                    {
                        "refreshed": 0,
                        "empty": 0,
                        "languages": [],
                        "dry_run": args.dry_run,
                    },
                    indent=2,
                )
            )
            return 0

        summary = refresh_bundles(langs, dry_run=args.dry_run)
        print(
            json.dumps(
                {
                    "dry_run": args.dry_run,
                    "languages": langs,
                    **summary,
                },
                indent=2,
                ensure_ascii=False,
            )
        )
        return 0
    except Exception as exc:  # noqa: BLE001
        print(f"Refresh failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
