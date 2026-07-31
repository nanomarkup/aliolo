#!/usr/bin/env python3
import csv
import json
import math
import subprocess
from collections import Counter, defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
API_DIR = ROOT / "api"
TMP_DIR = ROOT / "scripts" / ".tmp"
DB_NAME = "aliolo-db"

BACKUP_PATH = TMP_DIR / "card_levels_backup.json"
DETAIL_REPORT_PATH = TMP_DIR / "card_levels_report.csv"
SUMMARY_REPORT_PATH = TMP_DIR / "card_levels_summary.csv"
SQL_PATH = TMP_DIR / "normalize_card_levels_three_tiers.sql"


FORCE_SINGLE_LEVEL_NAMES = {
    "human organ systems",
}

FORCE_SINGLE_LEVEL_PREFIXES = (
    "addition ",
    "subtraction ",
    "counting ",
    "numbers ",
    "multiply ",
    "divide ",
)

FORCE_SINGLE_LEVEL_SUFFIXES = (" alphabet",)


def shell_quote(value: str) -> str:
    return "'" + str(value).replace("'", "'\"'\"'") + "'"


def sql_literal(value):
    if value is None:
        return "NULL"
    return "'" + str(value).replace("'", "''") + "'"


def run_wrangler(args, *, json_output=False):
    command = [
        "bash",
        "-lc",
        "source /home/vitaliinoga/.config/nvm/nvm.sh "
        "&& nvm use --lts >/dev/null "
        "&& node node_modules/wrangler/bin/wrangler.js " + " ".join(shell_quote(arg) for arg in args),
    ]
    result = subprocess.run(command, cwd=API_DIR, capture_output=True, text=True)
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or f"exit {result.returncode}"
        raise RuntimeError(detail)
    if json_output:
        return json.loads(result.stdout)
    return result.stdout


def fetch_subjects():
    sql = (
        "SELECT s.id, s.name, COUNT(c.id) AS card_count "
        "FROM subjects s "
        "LEFT JOIN cards c ON c.subject_id = s.id "
        "GROUP BY s.id, s.name "
        "ORDER BY s.name"
    )
    payload = run_wrangler(
        ["d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"],
        json_output=True,
    )
    return payload[0]["results"]


def fetch_cards():
    sql = "SELECT id, subject_id, answer, level FROM cards ORDER BY subject_id, level, answer, id"
    payload = run_wrangler(
        ["d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"],
        json_output=True,
    )
    return payload[0]["results"]


def is_forced_single_level(subject_name: str) -> bool:
    normalized = subject_name.strip().lower()
    if normalized in FORCE_SINGLE_LEVEL_NAMES:
        return True
    if normalized.startswith(FORCE_SINGLE_LEVEL_PREFIXES):
        return True
    if normalized.endswith(FORCE_SINGLE_LEVEL_SUFFIXES):
        return True
    return False


def compute_subject_policy(subject_name: str, cards: list[dict]) -> str:
    if is_forced_single_level(subject_name):
        return "single_level"
    levels = {int(card["level"] or 1) for card in cards}
    if len(levels) <= 1:
        return "single_level"
    return "quantized_existing_order"


def assign_single_level(cards: list[dict]) -> dict[str, int]:
    return {card["id"]: 1 for card in cards}


def assign_quantized_levels(cards: list[dict]) -> dict[str, int]:
    sorted_cards = sorted(
        cards,
        key=lambda card: (
            int(card["level"] or 1),
            str(card["answer"] or "").casefold(),
            card["id"],
        ),
    )
    total = len(sorted_cards)
    first_cut = math.ceil(total / 3)
    second_cut = math.ceil((2 * total) / 3)

    assignments = {}
    for index, card in enumerate(sorted_cards):
        if index < first_cut:
            level = 1
        elif index < second_cut:
            level = 2
        else:
            level = 3
        assignments[card["id"]] = level
    return assignments


def build_updates(subjects: list[dict], cards: list[dict]):
    subject_lookup = {subject["id"]: subject for subject in subjects}
    by_subject = defaultdict(list)
    for card in cards:
        by_subject[card["subject_id"]].append(card)

    updates = []
    summaries = []

    for subject in subjects:
        subject_cards = by_subject.get(subject["id"], [])
        if not subject_cards:
            summaries.append(
                {
                    "subject_id": subject["id"],
                    "subject_name": subject["name"],
                    "card_count": 0,
                    "policy": "no_cards",
                    "level_1": 0,
                    "level_2": 0,
                    "level_3": 0,
                    "changed_cards": 0,
                }
            )
            continue

        policy = compute_subject_policy(subject["name"], subject_cards)
        if policy == "single_level":
            assignments = assign_single_level(subject_cards)
        elif policy == "quantized_existing_order":
            assignments = assign_quantized_levels(subject_cards)
        else:
            raise RuntimeError(f"Unhandled policy {policy}")

        distribution = Counter(assignments.values())
        changed_cards = 0

        for card in sorted(subject_cards, key=lambda item: (str(item["answer"] or "").casefold(), item["id"])):
            old_level = int(card["level"] or 1)
            new_level = assignments[card["id"]]
            if old_level != new_level:
                changed_cards += 1
            updates.append(
                {
                    "subject_id": subject["id"],
                    "subject_name": subject["name"],
                    "card_id": card["id"],
                    "answer": card["answer"],
                    "old_level": old_level,
                    "new_level": new_level,
                    "policy": policy,
                }
            )

        summaries.append(
            {
                "subject_id": subject["id"],
                "subject_name": subject["name"],
                "card_count": len(subject_cards),
                "policy": policy,
                "level_1": distribution.get(1, 0),
                "level_2": distribution.get(2, 0),
                "level_3": distribution.get(3, 0),
                "changed_cards": changed_cards,
            }
        )

    return updates, summaries


def write_sql(updates: list[dict]):
    lines = []
    for update in updates:
        lines.append(
            "UPDATE cards "
            f"SET level = {update['new_level']}, updated_at = CURRENT_TIMESTAMP "
            f"WHERE id = {sql_literal(update['card_id'])};"
        )
    SQL_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_reports(updates: list[dict], summaries: list[dict], cards: list[dict]):
    BACKUP_PATH.write_text(json.dumps(cards, indent=2), encoding="utf-8")

    with DETAIL_REPORT_PATH.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "subject_id",
                "subject_name",
                "card_id",
                "answer",
                "old_level",
                "new_level",
                "policy",
            ],
        )
        writer.writeheader()
        writer.writerows(updates)

    with SUMMARY_REPORT_PATH.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "subject_id",
                "subject_name",
                "card_count",
                "policy",
                "level_1",
                "level_2",
                "level_3",
                "changed_cards",
            ],
        )
        writer.writeheader()
        writer.writerows(summaries)


def execute_sql():
    run_wrangler(["d1", "execute", DB_NAME, "--remote", "--file", str(SQL_PATH)])


def verify():
    sql = (
        "SELECT "
        "COUNT(*) AS total_cards, "
        "SUM(CASE WHEN level = 1 THEN 1 ELSE 0 END) AS level_1, "
        "SUM(CASE WHEN level = 2 THEN 1 ELSE 0 END) AS level_2, "
        "SUM(CASE WHEN level = 3 THEN 1 ELSE 0 END) AS level_3, "
        "SUM(CASE WHEN level NOT IN (1, 2, 3) THEN 1 ELSE 0 END) AS outside_range "
        "FROM cards"
    )
    payload = run_wrangler(
        ["d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"],
        json_output=True,
    )
    return payload[0]["results"][0]


def main():
    TMP_DIR.mkdir(parents=True, exist_ok=True)
    subjects = fetch_subjects()
    cards = fetch_cards()
    updates, summaries = build_updates(subjects, cards)
    write_reports(updates, summaries, cards)
    write_sql(updates)
    execute_sql()
    verification = verify()

    if int(verification["outside_range"]) != 0:
        raise RuntimeError(f"Verification failed: {verification}")

    print(f"backup\t{BACKUP_PATH}")
    print(f"detail_report\t{DETAIL_REPORT_PATH}")
    print(f"summary_report\t{SUMMARY_REPORT_PATH}")
    print(f"sql\t{SQL_PATH}")
    print(f"verification\t{json.dumps(verification)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
