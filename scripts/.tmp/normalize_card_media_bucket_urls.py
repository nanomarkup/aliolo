#!/usr/bin/env python3
import argparse
import csv
import json
import subprocess
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
API_DIR = ROOT / "api"
REPORT_DIR = ROOT / "scripts" / ".tmp"
DB_NAME = "aliolo-db"
FIELDS = ("images_base", "images_local", "audio", "audios", "video", "videos")
ALIASES = ("card_images", "card_audio", "card_videos", "feedback_attachments")


def shell_quote(value: str) -> str:
    return "'" + value.replace("'", "'\"'\"'") + "'"


def run_wrangler(args: list[str], *, json_output: bool = False) -> str | list[dict]:
    command = (
        "source /home/vitaliinoga/.config/nvm/nvm.sh "
        "&& nvm use --lts >/dev/null "
        "&& node node_modules/wrangler/bin/wrangler.js "
        + " ".join(shell_quote(arg) for arg in args)
    )
    result = subprocess.run(["bash", "-lc", command], cwd=API_DIR, capture_output=True, text=True)
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or f"exit {result.returncode}"
        raise RuntimeError(detail)
    return json.loads(result.stdout) if json_output else result.stdout


def sql_literal(value: str | None) -> str:
    if value is None:
        return "NULL"
    return "'" + value.replace("'", "''") + "'"


def normalize(value: object) -> object:
    if not isinstance(value, str):
        return value
    updated = value
    for alias in ALIASES:
        updated = updated.replace(
            f"/storage/v1/object/public/{alias}/",
            "/storage/v1/object/public/aliolo-media/",
        )
    return updated


def fetch_cards() -> list[dict]:
    sql = "SELECT id, " + ", ".join(FIELDS) + " FROM cards ORDER BY id"
    payload = run_wrangler(
        ["d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"],
        json_output=True,
    )
    return payload[0]["results"]


def update_card(card_id: str, changes: dict[str, str | None]) -> None:
    assignments = ", ".join(f"{field} = {sql_literal(value)}" for field, value in changes.items())
    sql = f"UPDATE cards SET {assignments}, updated_at = CURRENT_TIMESTAMP WHERE id = {sql_literal(card_id)}"
    run_wrangler(["d1", "execute", DB_NAME, "--command", sql, "--remote"])


def remaining_alias_counts() -> dict[str, int]:
    select_parts = []
    for field in FIELDS:
        condition = " OR ".join(
            f"{field} LIKE '%/storage/v1/object/public/{alias}/%'" for alias in ALIASES
        )
        select_parts.append(f"SUM(CASE WHEN {condition} THEN 1 ELSE 0 END) AS {field}")
    sql = "SELECT " + ", ".join(select_parts) + " FROM cards"
    payload = run_wrangler(
        ["d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"],
        json_output=True,
    )
    return payload[0]["results"][0]


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Replace card media pseudo-bucket URL path segments with aliolo-media."
    )
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    timestamp = int(time.time())
    backup_path = REPORT_DIR / f"card_media_bucket_url_backup_{timestamp}.json"
    report_path = REPORT_DIR / f"card_media_bucket_url_report_{timestamp}.csv"

    cards = fetch_cards()
    changes_by_card: list[dict] = []
    backup_rows: list[dict] = []

    for card in cards:
        field_changes: dict[str, str | None] = {}
        changed_fields: list[str] = []
        for field in FIELDS:
            original = card.get(field)
            updated = normalize(original)
            if updated != original:
                field_changes[field] = updated
                changed_fields.append(field)

        if field_changes:
            backup_rows.append(card)
            changes_by_card.append(
                {
                    "id": card["id"],
                    "fields": changed_fields,
                    "values": field_changes,
                }
            )

    backup_path.write_text(json.dumps(backup_rows, indent=2, ensure_ascii=False), encoding="utf-8")
    with report_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=["card_id", "changed_fields"])
        writer.writeheader()
        for item in changes_by_card:
            writer.writerow({"card_id": item["id"], "changed_fields": ",".join(item["fields"])})

    if not args.dry_run:
        for item in changes_by_card:
            update_card(item["id"], item["values"])

    remaining = remaining_alias_counts() if not args.dry_run else {}
    print(
        json.dumps(
            {
                "dry_run": args.dry_run,
                "cards_scanned": len(cards),
                "cards_changed": len(changes_by_card),
                "field_updates": sum(len(item["fields"]) for item in changes_by_card),
                "backup_path": str(backup_path),
                "report_path": str(report_path),
                "remaining_alias_counts": remaining,
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
