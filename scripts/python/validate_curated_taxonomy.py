#!/usr/bin/env python3

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "api" / "config" / "curated_taxonomy.json"
SUBJECTS_DUMP_PATH = ROOT / "subjects_dump.json"


def load_manifest() -> dict:
    with MANIFEST_PATH.open() as f:
        return json.load(f)


def load_dump_subjects() -> list[dict]:
    with SUBJECTS_DUMP_PATH.open() as f:
        dump = json.load(f)
    return dump[0]["results"]


def flatten_manifest_subjects(manifest: dict) -> list[dict]:
    subjects: list[dict] = []
    for pillar in manifest["pillars"]:
        for subject in pillar.get("subjects", []):
            subjects.append(
                {
                    "pillar": pillar["name"],
                    "folder": None,
                    **subject,
                }
            )
        for folder in pillar.get("folders", []):
            for subject in folder.get("subjects", []):
                subjects.append(
                    {
                        "pillar": pillar["name"],
                        "folder": folder["name"],
                        **subject,
                    }
                )
    return subjects


def ensure(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def main() -> None:
    manifest = load_manifest()
    dump_subjects = load_dump_subjects()
    manifest_subjects = flatten_manifest_subjects(manifest)

    manifest_ids = [subject["id"] for subject in manifest_subjects]
    dump_ids = [subject["id"] for subject in dump_subjects]

    ensure(len(manifest["pillars"]) == 8, "Expected exactly 8 pillars.")
    ensure(
        [pillar["sort_order"] for pillar in manifest["pillars"]] == [1, 2, 3, 4, 5, 6, 7, 8],
        "Pillar sort order must stay contiguous from 1 to 8.",
    )
    ensure(
        len(manifest_ids) == len(set(manifest_ids)),
        "Manifest contains duplicate subject IDs.",
    )
    ensure(
        len(manifest_ids) == len(dump_ids),
        "Manifest subject count does not match the active subject dump.",
    )
    ensure(
        set(manifest_ids) == set(dump_ids),
        "Manifest subject IDs do not match the active subject dump.",
    )
    ensure(
        all(pillar["description"].strip() for pillar in manifest["pillars"]),
        "Every pillar must have a non-empty description.",
    )
    ensure(
        all(subject["description"].strip() for subject in manifest_subjects),
        "Every curated subject must have a non-empty description.",
    )
    ensure(
        all(len(folder["subjects"]) >= 2 for pillar in manifest["pillars"] for folder in pillar.get("folders", [])),
        "Single-subject folders are not allowed in the curated taxonomy.",
    )

    other = next((pillar for pillar in manifest["pillars"] if pillar["name"] == "Other"), None)
    ensure(other is not None, "The Other pillar is missing.")
    ensure(len(other["folders"]) == 0, "The Other pillar must not contain curated folders.")
    ensure(len(other["subjects"]) == 0, "The Other pillar must not contain curated subjects by default.")

    print(
        f"Validated curated taxonomy: {len(manifest['pillars'])} pillars, "
        f"{len(manifest_subjects)} subjects, {sum(len(p.get('folders', [])) for p in manifest['pillars'])} folders."
    )


if __name__ == "__main__":
    main()
