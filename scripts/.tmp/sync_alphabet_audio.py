#!/usr/bin/env python3
import argparse
import csv
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
API_DIR = ROOT / "api"
REPORT_DIR = ROOT / "scripts" / ".tmp"
WORK_DIR = REPORT_DIR / "alphabet_audio"
DB_NAME = "aliolo-db"
R2_BUCKET = "aliolo-media"
BASE_URL = "https://aliolo.com"

EXPECTED_SUBJECTS = {
    "Arabic Alphabet",
    "Bulgarian Alphabet",
    "Chinese Alphabet",
    "Croatian Alphabet",
    "Czech Alphabet",
    "Danish Alphabet",
    "Dutch Alphabet",
    "English Alphabet",
    "Estonian Alphabet",
    "Finnish Alphabet",
    "French Alphabet",
    "German Alphabet",
    "Greek Alphabet",
    "Hindi Alphabet",
    "Hungarian Alphabet",
    "Indonesian Alphabet",
    "Irish Alphabet",
    "Italian Alphabet",
    "Japanese Alphabet",
    "Korean Alphabet",
    "Latvian Alphabet",
    "Lithuanian Alphabet",
    "Maltese Alphabet",
    "Polish Alphabet",
    "Portuguese Alphabet",
    "Romanian Alphabet",
    "Slovak Alphabet",
    "Slovenian Alphabet",
    "Spanish Alphabet",
    "Swedish Alphabet",
    "Tagalog Alphabet",
    "Turkish Alphabet",
    "Ukrainian Alphabet",
    "Vietnamese Alphabet",
}

# espeak-ng does not expose a Tagalog voice in this environment, so we fall
# back to a close Latin-script voice that still lets us generate local audio.
SUBJECT_VOICES: dict[str, tuple[str, ...]] = {
    "Arabic": ("ar",),
    "Bulgarian": ("bg",),
    "Chinese": ("cmn",),
    "Croatian": ("hr",),
    "Czech": ("cs",),
    "Danish": ("da",),
    "Dutch": ("nl",),
    "English": ("en-us",),
    "Estonian": ("et",),
    "Finnish": ("fi",),
    "French": ("fr-fr",),
    "German": ("de",),
    "Greek": ("el",),
    "Hindi": ("hi",),
    "Hungarian": ("hu",),
    "Indonesian": ("id",),
    "Irish": ("ga",),
    "Italian": ("it",),
    "Japanese": ("ja",),
    "Korean": ("ko",),
    "Latvian": ("lv",),
    "Lithuanian": ("lt",),
    "Maltese": ("mt",),
    "Polish": ("pl",),
    "Portuguese": ("pt",),
    "Romanian": ("ro",),
    "Slovak": ("sk",),
    "Slovenian": ("sl",),
    "Spanish": ("es",),
    "Swedish": ("sv",),
    "Tagalog": ("id", "en-us"),
    "Turkish": ("tr",),
    "Ukrainian": ("uk",),
    "Vietnamese": ("vi",),
}


def shell_quote(value: str) -> str:
    return "'" + str(value).replace("'", "'\"'\"'") + "'"


def sql_literal(value: str | None) -> str:
    if value is None:
        return "NULL"
    return "'" + value.replace("'", "''") + "'"


def run_wrangler(args: list[str], *, json_output: bool = False):
    command = [
        "bash",
        "-lc",
        "source /home/vitaliinoga/.config/nvm/nvm.sh "
        "&& nvm use --lts >/dev/null "
        "&& node node_modules/wrangler/bin/wrangler.js "
        + " ".join(shell_quote(arg) for arg in args),
    ]
    result = subprocess.run(command, cwd=API_DIR, capture_output=True, text=True)
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or f"exit {result.returncode}"
        raise RuntimeError(detail)
    if json_output:
        return json.loads(result.stdout)
    return result.stdout


def fetch_subjects() -> list[dict]:
    sql = (
        "SELECT id, name "
        "FROM subjects "
        "WHERE name LIKE '% Alphabet' "
        "ORDER BY name"
    )
    payload = run_wrangler(
        ["d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"],
        json_output=True,
    )
    return payload[0]["results"]


def fetch_cards(subject_id: str) -> list[dict]:
    sql = (
        "SELECT id, subject_id, answer, audio, audios "
        "FROM cards "
        f"WHERE subject_id = {sql_literal(subject_id)} "
        "ORDER BY answer, id"
    )
    payload = run_wrangler(
        ["d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"],
        json_output=True,
    )
    return payload[0]["results"]


def available_espeak_voices() -> set[str]:
    result = subprocess.run(
        ["espeak-ng", "--voices"],
        capture_output=True,
        text=True,
        check=True,
    )
    voices: set[str] = set()
    for line in result.stdout.splitlines()[1:]:
        parts = line.split()
        if len(parts) >= 2:
            voices.add(parts[1])
    return voices


def resolve_voice(subject_name: str, available_voices: set[str]) -> tuple[str, bool]:
    language = subject_name.removesuffix(" Alphabet")
    candidates = SUBJECT_VOICES.get(language)
    if not candidates:
        raise RuntimeError(f"No TTS voice mapping defined for subject {subject_name}")
    for voice in candidates:
        if voice in available_voices:
            return voice, False
    # Fall back to the first configured candidate even if it is not listed.
    return candidates[0], True


def build_global_audio_key(card_id: str, timestamp_ms: int | None = None) -> str:
    if timestamp_ms is None:
        timestamp_ms = int(time.time() * 1000)
    return f"cards/{card_id}/global_{timestamp_ms}.mp3"


def synthesize_mp3(text: str, voice: str, output_path: Path) -> None:
    if not shutil.which("espeak-ng"):
        raise RuntimeError("espeak-ng is not installed")
    if not shutil.which("ffmpeg"):
        raise RuntimeError("ffmpeg is not installed")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="alphabet-audio-", dir=WORK_DIR) as temp_dir:
        temp_dir_path = Path(temp_dir)
        text_path = temp_dir_path / "text.txt"
        wav_path = temp_dir_path / "speech.wav"
        text_path.write_text(text, encoding="utf-8")

        subprocess.run(
            [
                "espeak-ng",
                "-v",
                voice,
                "-s",
                "120",
                "-w",
                str(wav_path),
                "-f",
                str(text_path),
            ],
            capture_output=True,
            text=True,
            check=True,
        )

        subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-loglevel",
                "error",
                "-i",
                str(wav_path),
                "-codec:a",
                "libmp3lame",
                "-q:a",
                "4",
                str(output_path),
            ],
            capture_output=True,
            text=True,
            check=True,
        )


def upload_to_r2(card_id: str, file_path: Path) -> str:
    r2_key = build_global_audio_key(card_id)
    run_wrangler(
        [
            "r2",
            "object",
            "put",
            f"{R2_BUCKET}/{r2_key}",
            "--file",
            str(file_path),
            "--content-type",
            "audio/mpeg",
            "--remote",
            "--force",
        ]
    )
    return r2_key


def update_card(card_id: str, public_url: str) -> None:
    sql = (
        "UPDATE cards "
        f"SET audio = {sql_literal(public_url)}, "
        "audios = '{}', "
        "updated_at = CURRENT_TIMESTAMP "
        f"WHERE id = {sql_literal(card_id)}"
    )
    run_wrangler(["d1", "execute", DB_NAME, "--command", sql, "--remote"])


def write_report(rows: list[dict], output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "status",
        "subject_name",
        "language",
        "card_id",
        "answer",
        "voice",
        "fallback_voice",
        "r2_key",
        "public_url",
        "error",
    ]
    with output_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow({key: row.get(key, "") for key in fieldnames})


def process_cards(dry_run: bool, limit: int | None, report_path: Path) -> int:
    subjects = fetch_subjects()
    subject_names = {subject["name"] for subject in subjects}
    missing_subjects = sorted(EXPECTED_SUBJECTS - subject_names)
    extra_subjects = sorted(subject_names - EXPECTED_SUBJECTS)
    if missing_subjects or extra_subjects:
        raise RuntimeError(
            "Unexpected alphabet subject set: "
            f"missing={missing_subjects} extra={extra_subjects}"
        )

    available_voices = available_espeak_voices()
    WORK_DIR.mkdir(parents=True, exist_ok=True)

    report_rows: list[dict] = []
    summary = {"updated": 0, "skipped": 0, "failed": 0}

    for subject in subjects:
        subject_name = subject["name"]
        language = subject_name.removesuffix(" Alphabet")
        voice, used_fallback = resolve_voice(subject_name, available_voices)
        cards = fetch_cards(subject["id"])
        if limit is not None:
            cards = cards[:limit]

        print(f"Subject: {subject_name} ({len(cards)} cards) voice={voice}")

        for card in cards:
            card_id = card["id"]
            answer = (card.get("answer") or "").strip()
            if not answer:
                summary["skipped"] += 1
                report_rows.append(
                    {
                        "status": "skipped",
                        "subject_name": subject_name,
                        "language": language,
                        "card_id": card_id,
                        "answer": "",
                        "voice": voice,
                        "fallback_voice": "yes" if used_fallback else "",
                        "r2_key": "",
                        "public_url": "",
                        "error": "Empty answer text",
                    }
                )
                continue

            output_path = WORK_DIR / f"{card_id}.mp3"
            if dry_run:
                r2_key = build_global_audio_key(card_id)
                public_url = f"{BASE_URL}/storage/v1/object/public/{R2_BUCKET}/{r2_key}"
                summary["updated"] += 1
                report_rows.append(
                    {
                        "status": "matched",
                        "subject_name": subject_name,
                        "language": language,
                        "card_id": card_id,
                        "answer": answer,
                        "voice": voice,
                        "fallback_voice": "yes" if used_fallback else "",
                        "r2_key": r2_key,
                        "public_url": public_url,
                        "error": "",
                    }
                )
                continue

            try:
                synthesize_mp3(answer, voice, output_path)
                r2_key = upload_to_r2(card_id, output_path)
                public_url = f"{BASE_URL}/storage/v1/object/public/{R2_BUCKET}/{r2_key}"
                update_card(card_id, public_url)
                summary["updated"] += 1
                report_rows.append(
                    {
                        "status": "updated",
                        "subject_name": subject_name,
                        "language": language,
                        "card_id": card_id,
                        "answer": answer,
                        "voice": voice,
                        "fallback_voice": "yes" if used_fallback else "",
                        "r2_key": r2_key,
                        "public_url": public_url,
                        "error": "",
                    }
                )
                print(f"UPDATE {subject_name} {answer} -> {public_url}")
            except (RuntimeError, subprocess.CalledProcessError, OSError) as exc:
                summary["failed"] += 1
                report_rows.append(
                    {
                        "status": "failed",
                        "subject_name": subject_name,
                        "language": language,
                        "card_id": card_id,
                        "answer": answer,
                        "voice": voice,
                        "fallback_voice": "yes" if used_fallback else "",
                        "r2_key": "",
                        "public_url": "",
                        "error": str(exc),
                    }
                )
                print(f"FAIL   {subject_name} {answer}: {exc}", file=sys.stderr)
            finally:
                if output_path.exists():
                    output_path.unlink()

    write_report(report_rows, report_path)
    print(
        json.dumps(
            {
                "dry_run": dry_run,
                "subjects": len(subjects),
                "cards_processed": sum(1 for row in report_rows if row["status"] != "skipped"),
                "updated": summary["updated"],
                "skipped": summary["skipped"],
                "failed": summary["failed"],
                "report_path": str(report_path),
            },
            indent=2,
        )
    )
    return 0 if summary["failed"] == 0 else 1


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate and upload one base audio per card for alphabet subjects."
    )
    parser.add_argument("--dry-run", action="store_true", help="Do not mutate D1 or R2.")
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="Process only the first N cards per subject.",
    )
    parser.add_argument(
        "--report",
        default=str(REPORT_DIR / "alphabet_audio_report.csv"),
        help="CSV path for per-card results.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    report_path = Path(args.report)
    try:
        return process_cards(dry_run=args.dry_run, limit=args.limit, report_path=report_path)
    except Exception as exc:
        print(f"Fatal error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
