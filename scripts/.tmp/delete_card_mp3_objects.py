#!/usr/bin/env python3
import argparse
import csv
import json
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
API_DIR = ROOT / "api"
R2_BUCKET = "aliolo-media"


def shell_quote(value: str) -> str:
    return "'" + str(value).replace("'", "'\"'\"'") + "'"


def run_wrangler(args: list[str]) -> None:
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


def load_object_paths(report_path: Path) -> list[str]:
    paths: list[str] = []
    with report_path.open(encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            for field in ("deleted_objects",):
                value = (row.get(field) or "").strip()
                if not value:
                    continue
                for object_path in value.split(","):
                    object_path = object_path.strip()
                    if object_path:
                        paths.append(object_path)
    seen: set[str] = set()
    unique_paths: list[str] = []
    for path in paths:
        if path in seen:
            continue
        seen.add(path)
        unique_paths.append(path)
    return unique_paths


def delete_one(object_path: str) -> tuple[str, Exception | None]:
    try:
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
        return object_path, None
    except Exception as exc:
        return object_path, exc


def delete_objects(paths: list[str], workers: int) -> int:
    failed = 0
    completed = 0
    total = len(paths)
    with ThreadPoolExecutor(max_workers=workers) as executor:
        futures = [executor.submit(delete_one, path) for path in paths]
        for future in as_completed(futures):
            object_path, error = future.result()
            completed += 1
            if error is None:
                if completed % 25 == 0 or completed == total:
                    print(f"deleted {completed}/{total}")
            else:
                failed += 1
                print(f"FAIL {object_path}: {error}", file=sys.stderr)
    print(json.dumps({"deleted": total - failed, "failed": failed}, indent=2))
    return 0 if failed == 0 else 1


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Delete mp3 objects listed in a cleanup report.")
    parser.add_argument(
        "--report",
        default=str(ROOT / "scripts" / ".tmp" / "delete_card_mp3_media_report.csv"),
        help="CSV report with deleted_objects columns.",
    )
    parser.add_argument(
        "--workers",
        type=int,
        default=6,
        help="How many parallel delete workers to use.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    return delete_objects(load_object_paths(Path(args.report)), workers=args.workers)


if __name__ == "__main__":
    raise SystemExit(main())
