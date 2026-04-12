import requests
import json
import time

URL = "https://mltdjjszycfmokwqsqxm.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
headers = {"apikey": KEY, "Authorization": "Bearer " + KEY, "Content-Type": "application/json"}

# Languages to check for non-latin characters
CHECK_LANGS = ["ar", "hi", "ja", "ko", "zh", "uk", "bg", "el"]

def find_cards_to_translate():
    print("Fetching subjects to identify Academic pillar cards...")
    res_sub = requests.get(f"{URL}/rest/v1/subjects?pillar_id=eq.6&select=id", headers=headers)
    academic_subject_ids = {s["id"] for s in res_sub.json()}
    
    print(f"Skipping cards from {len(academic_subject_ids)} academic subjects.")

    all_to_translate = []
    offset = 0
    limit = 1000
    total_checked = 0

    while True:
        res = requests.get(f"{URL}/rest/v1/cards?select=id,subject_id,localized_data&limit={limit}&offset={offset}", headers=headers)
        cards = res.json()
        if not cards: break
        
        for card in cards:
            total_checked += 1
            if card["subject_id"] in academic_subject_ids:
                continue
            
            loc = card.get("localized_data", {})
            if not loc: continue
            
            global_data = loc.get("global", {})
            g_prompt = str(global_data.get("prompt") or "").strip().lower()
            g_answer = str(global_data.get("answer") or "").strip().lower()
            
            if not g_prompt and not g_answer:
                continue

            needs_update = False
            for lang in CHECK_LANGS:
                l_data = loc.get(lang, {})
                # More robust handling of potential nulls
                l_prompt = str(l_data.get("prompt") or "").strip().lower()
                l_answer = str(l_data.get("answer") or "").strip().lower()
                
                if not l_prompt or not l_answer or l_prompt == g_prompt or l_answer == g_answer:
                    needs_update = True
                    break
            
            if needs_update:
                all_to_translate.append({
                    "id": card["id"],
                    "prompt": global_data.get("prompt"),
                    "answer": global_data.get("answer")
                })

            if total_checked % 100 == 0:
                print(f"Checked {total_checked} cards... Found {len(all_to_translate)} needing fix.")

        if len(cards) < limit: break
        offset += limit

    print(f"Finished search. Total cards needing update: {len(all_to_translate)}")
    
    with open("cards_to_translate.json", "w") as f:
        json.dump(all_to_translate, f, indent=2)

if __name__ == "__main__":
    find_cards_to_translate()
