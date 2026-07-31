#!/usr/bin/env python3

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "api" / "config" / "curated_taxonomy.json"


def sql_string(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def load_manifest() -> dict:
    with MANIFEST_PATH.open() as f:
        return json.load(f)


def iter_subjects(manifest: dict):
    for pillar in manifest["pillars"]:
        for subject in pillar.get("subjects", []):
            yield {
                "pillar_sort_order": pillar["sort_order"],
                "folder_id": None,
                **subject,
            }
        for folder in pillar.get("folders", []):
            for subject in folder.get("subjects", []):
                yield {
                    "pillar_sort_order": pillar["sort_order"],
                    "folder_id": folder["id"],
                    **subject,
                }


def main() -> None:
    manifest = load_manifest()

    print("-- Generated from api/config/curated_taxonomy.json")
    print("-- Applies the curated Aliolo taxonomy without touching user-created content.")
    print("-- Review before running against production data.")
    print("-- Do not wrap this file in SQL BEGIN/COMMIT when running through Durable Objects or D1 APIs.")
    print()

    print("-- Update pillar names and descriptions by sort order.")
    for pillar in manifest["pillars"]:
        print(
            "UPDATE pillars "
            f"SET name = {sql_string(pillar['name'])}, "
            f"description = {sql_string(pillar['description'])} "
            f"WHERE sort_order = {pillar['sort_order']};"
        )
    print()

    print("-- Upsert curated folders.")
    for pillar in manifest["pillars"]:
        for folder in pillar.get("folders", []):
            print(
                "INSERT INTO folders (id, pillar_id, owner_id, name, names, created_at, updated_at) "
                f"SELECT {sql_string(folder['id'])}, "
                "p.id, "
                "COALESCE("
                "(SELECT id FROM profiles WHERE username = 'Aliolo' LIMIT 1), "
                "(SELECT owner_id FROM subjects LIMIT 1)"
                "), "
                f"{sql_string(folder['name'])}, "
                "'{}', "
                "COALESCE((SELECT created_at FROM folders WHERE id = "
                f"{sql_string(folder['id'])}), CURRENT_TIMESTAMP), "
                "CURRENT_TIMESTAMP "
                "FROM pillars p "
                f"WHERE p.sort_order = {pillar['sort_order']} "
                "ON CONFLICT(id) DO UPDATE SET "
                "pillar_id = excluded.pillar_id, "
                "owner_id = excluded.owner_id, "
                "name = excluded.name, "
                "names = excluded.names, "
                "updated_at = CURRENT_TIMESTAMP;"
            )
    print()

    print("-- Move curated subjects, rename them, and refresh descriptions.")
    for subject in iter_subjects(manifest):
        folder_sql = "NULL" if subject["folder_id"] is None else sql_string(subject["folder_id"])
        print(
            "UPDATE subjects "
            "SET "
            f"pillar_id = (SELECT id FROM pillars WHERE sort_order = {subject['pillar_sort_order']} LIMIT 1), "
            f"folder_id = {folder_sql}, "
            f"name = {sql_string(subject['name'])}, "
            f"description = {sql_string(subject['description'])}, "
            "updated_at = CURRENT_TIMESTAMP "
            f"WHERE id = {sql_string(subject['id'])};"
        )
    print()


if __name__ == "__main__":
    main()
