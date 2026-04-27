import csv
import json

# This sample data was fetched from the DB and audited by Gemini
audit_data = [
    {
        "card_id": "c89379ae-3cdb-4173-a007-e646a1dedfc4",
        "subject_id": "2450ccd1-b439-4ed1-8280-30de3f41e400",
        "field": "answer",
        "locale": "tl",
        "global_text": "Dolphin",
        "current_text": "dolphin",
        "translated_text": "Dolphin",
        "status": "lowercase_warning"
    },
    {
        "card_id": "43085fab-1818-44db-9797-9d38e635052a",
        "subject_id": "4b210d48-c309-4c4b-ad80-24b9f8dde33e",
        "field": "answer",
        "locale": "es",
        "global_text": "THE UNITED KINGDOM, Fish and chips",
        "current_text": "REINO UNIDO, Fish and chips",
        "translated_text": "REINO UNIDO, Pescado con papas fritas",
        "status": "partial_translation"
    },
    {
        "card_id": "43085fab-1818-44db-9797-9d38e635052a",
        "subject_id": "4b210d48-c309-4c4b-ad80-24b9f8dde33e",
        "field": "answer",
        "locale": "fr",
        "global_text": "THE UNITED KINGDOM, Fish and chips",
        "current_text": "LE ROYAUME-UNI, Fish and chips",
        "translated_text": "LE ROYAUME-UNI, Poisson-frites",
        "status": "partial_translation"
    },
    {
        "card_id": "705f8af4-c8be-4867-bc1a-9b00d7dfe7fd",
        "subject_id": "5319e962-cd18-4e74-9cd7-8092ebe1752c",
        "field": "answer",
        "locale": "el",
        "global_text": "Pink Orchid Mantis",
        "current_text": "Pink Orchid Mantis",
        "translated_text": "Ροζ μαντίς ορχιδέα",
        "status": "untranslated_script_mismatch"
    },
    {
        "card_id": "bbce880f-0f4d-4015-8ff7-b37cae267d7a",
        "subject_id": "5319e962-cd18-4e74-9cd7-8092ebe1752c",
        "field": "answer",
        "locale": "es",
        "global_text": "Lantern Bug",
        "current_text": "Error de linterna",
        "translated_text": "Bicho linterna",
        "status": "contextual_error_bug_vs_error"
    },
    {
        "card_id": "bbce880f-0f4d-4015-8ff7-b37cae267d7a",
        "subject_id": "5319e962-cd18-4e74-9cd7-8092ebe1752c",
        "field": "answer",
        "locale": "pl",
        "global_text": "Lantern Bug",
        "current_text": "Błąd Latarni",
        "translated_text": "Pluskwiak latarnia",
        "status": "contextual_error_bug_vs_error"
    },
    {
        "card_id": "61612521-f2dc-429d-972b-273e28f266bf",
        "subject_id": "8efc96db-89ae-4137-91cd-6a5800b788ad",
        "field": "answer",
        "locale": "vi",
        "global_text": "Times Square",
        "current_text": "Quảng trường Thời đại",
        "translated_text": "Quảng trường Thời đại",
        "status": "correct"
    }
]

output_path = "aliolo/scripts/.tmp/translation_quality_report_sample.csv"
with open(output_path, "w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=["card_id", "subject_id", "field", "locale", "global_text", "current_text", "translated_text", "status"])
    writer.writeheader()
    for d in audit_data:
        writer.writerow(d)

print(f"Sample report saved to {output_path}")
