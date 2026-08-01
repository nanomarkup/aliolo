#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
API_DIR = ROOT / "api"
WRANGLER_BIN = API_DIR / "node_modules" / "wrangler" / "bin" / "wrangler.js"
DB_NAME = "aliolo-db"
R2_BUCKET = "aliolo-media"
R2_PREFIX = "translations"

ASSETS_DIR = ROOT / "assets" / "translations"
SQL_SEED_PATH = ROOT / "scripts" / "sql" / "generated_ui_translations.sql"

SQL_ROW_RE = re.compile(
    r"^\s*\('(?P<key>(?:[^']|'{2})+)'\s*,\s*'(?P<lang>[^']+)'\s*,\s*'(?P<value>(?:[^']|'{2})*)'\s*,\s*CURRENT_TIMESTAMP\),?\s*$"
)


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
    raise RuntimeError("Node runtime not found.")


def wrangler_cmd() -> list[str]:
    return [resolve_node_bin(), str(WRANGLER_BIN)]


def shell_quote(value: str) -> str:
    return "'" + value.replace("'", "'\"'\"'") + "'"


def run_wrangler(args: list[str]) -> str:
    local_wrangler = API_DIR / "node_modules" / ".bin" / "wrangler"
    cmd_args = []
    
    if local_wrangler.exists():
        cmd_args = [str(local_wrangler)] + args
    else:
        cmd_args = wrangler_cmd() + args

    # Check if we can run it directly
    try:
        result = subprocess.run(cmd_args, cwd=API_DIR, capture_output=True, text=True)
        if result.returncode == 0:
            return result.stdout
    except Exception:
        pass

    # Fallback to sourcing nvm if needed
    home = Path.home()
    nvm_paths = [
        home / ".config" / "nvm" / "nvm.sh",
        home / ".nvm" / "nvm.sh",
    ]
    
    source_cmd = ""
    for nvm_path in nvm_paths:
        if nvm_path.exists():
            source_cmd = f"source {nvm_path} && nvm use --lts >/dev/null && "
            break

    command = f"{source_cmd}" + " ".join(shell_quote(arg) for arg in wrangler_cmd() + args)
    result = subprocess.run(["bash", "-lc", command], cwd=API_DIR, capture_output=True, text=True)
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or f"exit code {result.returncode}"
        raise RuntimeError(detail)
    return result.stdout


def to_nano(translations: dict[str, str]) -> str:
    lines = [".."]
    for k, v in sorted(translations.items()):
        # Escape any potential edge cases or keep simple.
        # Nano multiline is indicated by key| followed by indented lines.
        if '\n' in v and '\r' not in v and '\t' not in v and not v.endswith('\n') and all(line == '' or line.strip() != '' for line in v.split('\n')):
            lines.append(f"    {k}|")
            for line in v.split('\n'):
                lines.append(f"        {line}")
        else:
            if v and not v.startswith(' ') and not v.endswith(' ') and not v.startswith('"') and '\t' not in v and '\r' not in v and '\n' not in v:
                lines.append(f"    {k} {v}")
            else:
                escaped = v.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r', '\\r').replace('\t', '\\t')
                lines.append(f'    {k} "{escaped}"')
    return "\n".join(lines) + "\n"


def get_hash(content: str) -> str:
    return hashlib.md5(content.encode("utf-8")).hexdigest()[:8]


def upload_to_r2(local_path: Path, remote_key: str) -> None:
    print(f"Uploading {local_path.name} to r2://{R2_BUCKET}/{remote_key}")
    run_wrangler(["r2", "object", "put", f"{R2_BUCKET}/{remote_key}", "--file", str(local_path)])


def load_from_sql_file(path: Path) -> dict[str, dict[str, str]]:
    """Loads translations from generated_ui_translations.sql into a mapping of lang -> {key: value}"""
    if not path.exists():
        raise FileNotFoundError(f"SQL file not found at {path}")

    lang_translations: dict[str, dict[str, str]] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        match = SQL_ROW_RE.match(line)
        if not match:
            continue
        key = match.group("key").replace("''", "'")
        lang = match.group("lang").lower()
        value = match.group("value").replace("''", "'")
        lang_translations.setdefault(lang, {})[key] = value
    return lang_translations


def main() -> int:
    parser = argparse.ArgumentParser(description="Distribute UI translations as hashed Nano files to R2.")
    parser.add_argument("--skip-upload", action="store_true", help="Do not upload to R2, only generate files locally.")
    parser.add_argument("--import-from-sql", action="store_true", help="Import all translations from SQL seed file to local assets/translations/{lang}.nano.")
    args = parser.parse_args()

    try:
        ASSETS_DIR.mkdir(parents=True, exist_ok=True)
        tmp_dir = ROOT / "scripts" / ".tmp" / "translations"
        tmp_dir.mkdir(parents=True, exist_ok=True)

        if args.import_from_sql:
            print(f"Importing translations from {SQL_SEED_PATH}...")
            lang_map = load_from_sql_file(SQL_SEED_PATH)
            for lang, translations in lang_map.items():
                nano_content = to_nano(translations)
                lang_path = ASSETS_DIR / f"{lang}.nano"
                lang_path.write_text(nano_content, encoding="utf-8")
                print(f"Generated {lang_path} with {len(translations)} entries")
            print("Import complete.")
            return 0

        # Standard mode: read local files, hash, and upload to R2
        manifest = {}
        for file_path in sorted(ASSETS_DIR.glob("*.nano")):
            lang = file_path.stem
            print(f"Processing local translation: {lang}...")
            nano_content = file_path.read_text(encoding="utf-8")
            
            content_hash = get_hash(nano_content)
            manifest[lang] = content_hash

            # Prepare hashed file for R2
            hashed_name = f"{lang}.{content_hash}.nano"
            local_path = tmp_dir / hashed_name
            local_path.write_text(nano_content, encoding="utf-8")

            if not args.skip_upload:
                upload_to_r2(local_path, f"{R2_PREFIX}/{hashed_name}")

        # Generate and upload manifest
        manifest_path = tmp_dir / "manifest.json"
        manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
        if not args.skip_upload:
            upload_to_r2(manifest_path, f"{R2_PREFIX}/manifest.json")
        
        print("\nDistribution complete.")
        print(f"Manifest: {json.dumps(manifest, indent=2)}")

        return 0
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
