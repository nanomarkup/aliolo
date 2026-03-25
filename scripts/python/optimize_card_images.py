import urllib.request
import json
import ssl

SUPABASE_URL = "https://mltdjjszycfmokwqsqxm.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"

HEADERS = {
    "apikey": SERVICE_ROLE_KEY,
    "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
    "Content-Type": "application/json"
}

context = ssl._create_unverified_context()

def cleanup_images():
    print("Fetching all cards for image URL optimization...")
    # POST to list cards (to handle potential large number of cards)
    url = f"{SUPABASE_URL}/rest/v1/cards?select=id,localized_data"
    req = urllib.request.Request(url, headers=HEADERS)
    
    try:
        with urllib.request.urlopen(req, context=context) as response:
            cards = json.loads(response.read().decode("utf-8"))
            print(f"Optimizing {len(cards)} cards...")
            
            for c in cards:
                loc = c.get("localized_data", {})
                
                # 1. Find a source for image_urls (try global, then en, then any)
                image_source = None
                if loc.get("global", {}).get("image_urls"):
                    image_source = loc["global"]["image_urls"]
                else:
                    for l in loc.keys():
                        if loc[l].get("image_urls"):
                            image_source = loc[l]["image_urls"]
                            break
                
                if not image_source:
                    continue

                # 2. Set global image_urls
                if "global" not in loc: loc["global"] = {}
                loc["global"]["image_urls"] = image_source

                # 3. Strip image_urls from all specific languages
                for l in loc.keys():
                    if l != "global":
                        loc[l].pop("image_urls", None)
                
                # 4. Save optimized data
                patch_req = urllib.request.Request(f"{SUPABASE_URL}/rest/v1/cards?id=eq.{c['id']}", headers=HEADERS, method="PATCH")
                urllib.request.urlopen(patch_req, data=json.dumps({"localized_data": loc}).encode("utf-8"), context=context)
                
            print("✓ Database optimization complete. All images are now purely global.")
            
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    cleanup_images()
