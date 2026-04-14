import sys
import requests
import json

URL = "https://mltdjjszycfmokwqsqxm.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
headers = {"apikey": KEY, "Authorization": "Bearer " + KEY, "Content-Type": "application/json"}

def main():
    print("--- Deduplicate Cards by Subject ---")
    
    try:
        subject_name = input("Enter the subject name (e.g., Dog Breeds): ").strip()
    except EOFError:
        print("Error: Could not read input.")
        sys.exit(1)
        
    if not subject_name:
        print("Error: Subject name cannot be empty.")
        sys.exit(1)
        
    print(f"\nFetching subject '{subject_name}'...")
    res = requests.get(f"{URL}/rest/v1/subjects?select=id,localized_data", headers=headers)
    
    if res.status_code != 200:
        print(f"Failed to fetch subjects. Error: {res.text}")
        sys.exit(1)
        
    subjects = res.json()
    subject_id = None
    for s in subjects:
        glob = s.get("localized_data", {}).get("global", {})
        if glob.get("name") == subject_name:
            subject_id = s["id"]
            break

    if not subject_id:
        print(f"Could not find subject '{subject_name}'. Please ensure the spelling and case are correct.")
        sys.exit(1)

    print(f"Found subject ID: {subject_id}")
    
    # Fetch cards for this subject
    res = requests.get(f"{URL}/rest/v1/cards?select=id,localized_data&subject_id=eq.{subject_id}", headers=headers)
    if res.status_code != 200:
        print(f"Failed to fetch cards. Error: {res.text}")
        sys.exit(1)

    cards = res.json()
    active_cards = cards

    print(f"Fetched {len(cards)} total cards.")    
    # Group by the global answer
    cards_by_answer = {}
    for card in active_cards:
        answer = card.get("localized_data", {}).get("global", {}).get("answer", "")
        # Lowercase and strip to catch minor differences as duplicates
        key = answer.strip().lower()
        if not key:
            continue
            
        if key not in cards_by_answer:
            cards_by_answer[key] = []
        cards_by_answer[key].append(card)
        
    # Find groups with >1 card
    duplicates = {}
    for key, group in cards_by_answer.items():
        if len(group) > 1:
            # Use original text from first item for display
            display_answer = group[0].get("localized_data", {}).get("global", {}).get("answer", "")
            duplicates[display_answer] = group
            
    if not duplicates:
        print("\nNo duplicated answers found in this subject. Everything looks good!")
        sys.exit(0)
        
    print("\n--- Found Duplicates ---")
    cards_to_delete = []
    
    for answer, group in duplicates.items():
        print(f"\nAnswer: '{answer}' ({len(group)} total cards, keeping 1)")
        for i, card in enumerate(group):
            if i == 0:
                print(f"  [KEEP]   ID: {card['id']}")
            else:
                print(f"  [DELETE] ID: {card['id']}")
                cards_to_delete.append(card['id'])
                
    print(f"\nTotal duplicate cards to delete: {len(cards_to_delete)}")
    
    try:
        confirm = input("Do you want to proceed and permanently delete these duplicates? (y/n): ").strip().lower()
    except EOFError:
        print("\nOperation cancelled.")
        sys.exit(1)
    
    if confirm in ['y', 'yes']:
        success_count = 0
        for idx, cid in enumerate(cards_to_delete):
            print(f"Deleting card {idx+1}/{len(cards_to_delete)} ({cid})...")
            
            # Using HTTP DELETE to physically remove the card
            del_res = requests.delete(f"{URL}/rest/v1/cards?id=eq.{cid}", headers=headers)
            
            if del_res.status_code in [200, 204]:
                success_count += 1
            else:
                print(f"  Failed to delete {cid}: HTTP {del_res.status_code} - {del_res.text}")
                
        print(f"\nDone. Successfully deleted {success_count} out of {len(cards_to_delete)} duplicate cards.")
    else:
        print("\nOperation cancelled. No cards were deleted.")

if __name__ == "__main__":
    main()
