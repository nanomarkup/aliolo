import requests
import json

url_base = "https://mltdjjszycfmokwqsqxm.supabase.co"
apikey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
headers = {
    "apikey": apikey,
    "Authorization": f"Bearer {apikey}"
}

subject_id = "0b84447d-3af3-4509-bdf6-c4e7fe822cc7"
langs = ['ar', 'bg', 'cs', 'da', 'de', 'el', 'en', 'es', 'et', 'fi', 'fr', 'ga', 'hi', 'hr', 'hu', 'id', 'it', 'ja', 'ko', 'lt', 'lv', 'mt', 'nl', 'pl', 'pt', 'ro', 'sk', 'sl', 'sv', 'tl', 'tr', 'uk', 'vi', 'zh']

def audit_colors():
    resp = requests.get(f"{url_base}/rest/v1/cards?subject_id=eq.{subject_id}&select=id,localized_data", headers=headers)
    cards = resp.json()
    
    missing_any = 0
    for card in cards:
        loc_data = card.get('localized_data', {})
        en_ans = loc_data.get('en', {}).get('answer', '').split(', ')[0]
        
        missing_langs = []
        for l in langs:
            if l == 'en': continue
            val = loc_data.get(l, {}).get('answer', '').split(', ')[0]
            if val == en_ans or not val:
                missing_langs.append(l)
        
        if missing_langs:
            missing_any += 1
            if missing_any <= 10:
                print(f"Card {en_ans} ({card['id']}) missing: {missing_langs}")
    
    print(f"\nTotal cards missing some translations: {missing_any} out of {len(cards)}")

if __name__ == "__main__":
    audit_colors()
