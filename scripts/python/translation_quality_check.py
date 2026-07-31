#!/usr/bin/env python3
import argparse
import csv
import json
import os
import shutil
import subprocess
import sys
import unicodedata
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Protocol
from concurrent.futures import ThreadPoolExecutor, as_completed

# Prerequisites:
# pip install google-cloud-translate
# gcloud auth application-default login

ROOT = Path(__file__).resolve().parents[2]
DB_NAME = "aliolo-db"
DEFAULT_OUTPUT = ROOT / "scripts" / ".tmp" / "translation_quality_report.csv"

FIELD_SPECS = [
    ("answer", "answers"),
    ("prompt", "prompts"),
    ("display_text", "display_texts"),
]

@dataclass(frozen=True)
class CardRecord:
    id: str
    subject_id: str
    prompt: str
    prompts: str
    answer: str
    answers: str
    display_text: str
    display_texts: str

@dataclass
class DiffRow:
    card_id: str
    subject_id: str
    field: str
    locale: str
    global_text: str
    current_text: str
    translated_text: str
    status: str

def resolve_node_bin() -> str:
    node_bin = shutil.which("node")
    if node_bin: return node_bin
    nvm_root = Path.home() / ".config" / "nvm" / "versions" / "node"
    if nvm_root.exists():
        for version_dir in sorted(nvm_root.iterdir(), reverse=True):
            candidate = version_dir / "bin" / "node"
            if candidate.exists(): return str(candidate)
    return "node"

def run_wrangler(args: list[str]) -> str:
    node = resolve_node_bin()
    wrangler = ROOT / "api" / "node_modules" / "wrangler" / "bin" / "wrangler.js"
    cmd = [node, str(wrangler)] + args
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Wrangler error: {result.stderr}", file=sys.stderr)
        return ""
    return result.stdout

def normalize(text: str) -> str:
    if not text: return ""
    # Remove punctuation, lowercase, strip
    text = "".join(ch for ch in text if not unicodedata.category(ch).startswith('P'))
    return unicodedata.normalize("NFC", text).strip().lower()

class GoogleTranslator:
    def __init__(self, project_id: str):
        from google.cloud import translate
        self.client = translate.TranslationServiceClient()
        self.parent = f"projects/{project_id}/locations/global"

    def translate(self, text: str, target_language: str) -> str:
        from google.cloud import translate
        if not text.strip(): return ""
        # Map some common codes
        if target_language == 'zh': target_language = 'zh-CN'
        
        response = self.client.translate_text(
            request={
                "parent": self.parent,
                "contents": [text],
                "mime_type": "text/plain",
                "source_language_code": "en-US",
                "target_language_code": target_language,
            }
        )
        return response.translations[0].translated_text

def main():
    parser = argparse.ArgumentParser(description="Check translation quality of cards.")
    parser.add_argument("--project-id", required=True, help="Google Cloud Project ID")
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT), help="Output CSV path")
    args = parser.parse_args()

    print("Fetching cards from D1...")
    sql = "SELECT id, subject_id, prompt, prompts, answer, answers, display_text, display_texts FROM cards"
    res = run_wrangler(["d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"])
    if not res: return
    
    cards_data = json.loads(res)[0]["results"]
    cards = [CardRecord(**c) for c in cards_data]
    print(f"Processing {len(cards)} cards...")

    translator = GoogleTranslator(args.project_id)
    diffs = []

    def check_card(card: CardRecord):
        card_diffs = []
        for global_field, local_field in FIELD_SPECS:
            global_val = getattr(card, global_field) or ""
            if not global_val.strip(): continue
            
            try:
                local_map = json.loads(getattr(card, local_field) or "{}")
            except:
                continue
            
            for locale, current_val in local_map.items():
                if not current_val: continue
                
                try:
                    translated = translator.translate(global_val, locale)
                    
                    if normalize(current_val) != normalize(translated):
                        card_diffs.append(DiffRow(
                            card_id=card.id,
                            subject_id=card.subject_id,
                            field=global_field,
                            locale=locale,
                            global_text=global_val,
                            current_text=current_val,
                            translated_text=translated,
                            status="mismatch"
                        ))
                except Exception as e:
                    print(f"Error translating card {card.id} to {locale}: {e}")
        return card_diffs

    # Using serial processing to avoid hitting heavy rate limits on free tiers, 
    # but ThreadPoolExecutor can be enabled if the user has high quotas.
    with ThreadPoolExecutor(max_workers=5) as executor:
        futures = [executor.submit(check_card, c) for c in cards]
        for future in as_completed(futures):
            diffs.extend(future.result())
            if len(diffs) % 10 == 0:
                print(f"Found {len(diffs)} potential issues so far...")

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    with open(output_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["card_id", "subject_id", "field", "locale", "global_text", "current_text", "translated_text", "status"])
        writer.writeheader()
        for d in diffs:
            writer.writerow({
                "card_id": d.card_id,
                "subject_id": d.subject_id,
                "field": d.field,
                "locale": d.locale,
                "global_text": d.global_text,
                "current_text": d.current_text,
                "translated_text": d.translated_text,
                "status": d.status
            })

    print(f"\nDone! Saved {len(diffs)} differences to {args.output}")

if __name__ == "__main__":
    main()
