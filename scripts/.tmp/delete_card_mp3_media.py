#!/usr/bin/env python3
import argparse
import csv
import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
API_DIR = ROOT / "api"
REPORT_DIR = ROOT / "scripts" / ".tmp"
DB_NAME = "aliolo-db"
R2_BUCKET = "aliolo-media"


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


def fetch_cards() -> list[dict]:
    sql = "SELECT id, answer, audio, audios FROM cards ORDER BY id"
    payload = run_wrangler(
        ["d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"],
        json_output=True,
    )
    return payload[0]["results"]


def parse_json_map(value) -> dict[str, str]:
    if value is None:
        return {}
    if isinstance(value, dict):
        return {str(k): str(v) for k, v in value.items() if v}
    text = str(value).strip()
    if not text:
        return {}
    try:
        parsed = json.loads(text)
    except json.JSONDecodeError:
        return {}
    if not isinstance(parsed, dict):
        return {}
    return {str(k): str(v) for k, v in parsed.items() if v}


def is_mp3_url(url: str) -> bool:
    return url.lower().endswith(".mp3")


def to_object_path(url: str) -> str | None:
    marker = f"/storage/v1/object/public/{R2_BUCKET}/"
    if marker in url:
        return url.split(marker, 1)[1]
    if url.startswith(f"{R2_BUCKET}/"):
        return url.split(f"{R2_BUCKET}/", 1)[1]
    return None


def delete_r2_object(object_path: str) -> None:
    run_wrangler(
        [
            "r2",
            "object",
            "delete",
            f"{R2_BUCKET}/{object_path}",
            "--remote",
            "--force",
        ]
    )


def update_card(card_id: str, audio_value: str | None, audios_value: dict[str, str]) -> None:
    sql = (
        "UPDATE cards "
        f"SET audio = {sql_literal(audio_value)}, "
        f"audios = {sql_literal(json.dumps(audios_value, ensure_ascii=False))}, "
        "updated_at = CURRENT_TIMESTAMP "
        f"WHERE id = {sql_literal(card_id)}"
    )
    run_wrangler(["d1", "execute", DB_NAME, "--command", sql, "--remote"])


def write_report(rows: list[dict], output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "status",
        "card_id",
        "answer",
        "deleted_objects",
        "removed_audios",
        "cleared_audio",
        "error",
    ]
    with output_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow({key: row.get(key, "") for key in fieldnames})


def process_cards(dry_run: bool, report_path: Path) -> int:
    cards = fetch_cards()
    summary = {"updated": 0, "skipped": 0, "failed": 0}
    report_rows: list[dict] = []
    seen_objects: set[str] = set()

    for card in cards:
        card_id = card["id"]
        answer = (card.get("answer") or "").strip()
        audio_url = (card.get("audio") or "").strip()
        audios_map = parse_json_map(card.get("audios"))

        deleted_objects: list[str] = []
        removed_langs: list[str] = []

        if audio_url and is_mp3_url(audio_url):
            object_path = to_object_path(audio_url)
            if object_path:
                deleted_objects.append(object_path)

        cleaned_audios: dict[str, str] = {}
        for lang, url in audios_map.items():
            if is_mp3_url(url):
                object_path = to_object_path(url)
                if object_path:
                    deleted_objects.append(object_path)
                    removed_langs.append(lang)
            else:
                cleaned_audios[lang] = url

        if not deleted_objects and not removed_langs:
            summary["skipped"] += 1
            continue

        deleted_objects = [path for path in deleted_objects if path not in seen_objects]
        for path in deleted_objects:
            seen_objects.add(path)

        if dry_run:
            summary["updated"] += 1
            report_rows.append(
                {
                    "status": "matched",
                    "card_id": card_id,
                    "answer": answer,
                    "deleted_objects": ",".join(deleted_objects),
                    "removed_audios": ",".join(removed_langs),
                    "cleared_audio": "yes" if bool(audio_url and is_mp3_url(audio_url)) else "",
                    "error": "",
                }
            )
            continue

        try:
            for object_path in deleted_objects:
                delete_r2_object(object_path)
            new_audio = None if (audio_url and is_mp3_url(audio_url)) else audio_url or None
            update_card(card_id, new_audio, cleaned_audios)
            summary["updated"] += 1
            report_rows.append(
                {
                    "status": "updated",
                    "card_id": card_id,
                    "answer": answer,
                    "deleted_objects": ",".join(deleted_objects),
                    "removed_audios": ",".join(removed_langs),
                    "cleared_audio": "yes" if bool(audio_url and is_mp3_url(audio_url)) else "",
                    "error": "",
                }
            )
        except Exception as exc:
            summary["failed"] += 1
            report_rows.append(
                {
                    "status": "failed",
                    "card_id": card_id,
                    "answer": answer,
                    "deleted_objects": ",".join(deleted_objects),
                    "removed_audios": ",".join(removed_langs),
                    "cleared_audio": "yes" if bool(audio_url and is_mp3_url(audio_url)) else "",
                    "error": str(exc),
                }
            )
            print(f"FAIL {card_id}: {exc}", file=sys.stderr)

    write_report(report_rows, report_path)
    print(
        json.dumps(
            {
                "dry_run": dry_run,
                "cards_scanned": len(cards),
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
        description="Delete mp3 card media objects and clear audio fields from D1."
    )
    parser.add_argument("--dry-run", action="store_true", help="Do not mutate D1 or R2.")
    parser.add_argument(
        "--report",
        default=str(REPORT_DIR / "delete_card_mp3_media_report.csv"),
        help="CSV path for per-card results.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        return process_cards(dry_run=args.dry_run, report_path=Path(args.report))
    except Exception as exc:
        print(f"Fatal error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
