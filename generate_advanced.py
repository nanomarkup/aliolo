import os
import json
import urllib.request
import urllib.parse
import uuid
import time
import ssl

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

CARDS_DIR = os.path.expanduser("~/.aliolo/cards")

ADVANCED_DATA = {
    "Astronomy": {
        1: ["Sun", "Mercury", "Venus", "Earth", "Moon", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune"],
        2: ["Pluto", "Ceres", "Eris", "Halley's Comet", "Andromeda Galaxy", "Milky Way", "Orion Nebula", "Crab Nebula", "Black hole", "Asteroid belt"],
        3: ["Solar eclipse", "Lunar eclipse", "Aurora Borealis", "Supernova", "Quasar", "Pulsar", "Red giant", "White dwarf", "Neutron star", "Exoplanet"]
    },
    "Flags of the World": {
        1: ["Flag of the United States", "Flag of the United Kingdom", "Flag of France", "Flag of Germany", "Flag of Japan", "Flag of Canada", "Flag of Australia", "Flag of Brazil", "Flag of China", "Flag of India"],
        2: ["Flag of Italy", "Flag of Spain", "Flag of Russia", "Flag of Mexico", "Flag of South Korea", "Flag of South Africa", "Flag of Egypt", "Flag of Argentina", "Flag of Sweden", "Flag of Norway"],
        3: ["Flag of Switzerland", "Flag of Greece", "Flag of Turkey", "Flag of Thailand", "Flag of Vietnam", "Flag of Israel", "Flag of New Zealand", "Flag of Ireland", "Flag of Portugal", "Flag of Poland"]
    },
    "World Landmarks": {
        11: ["Burj al-Arab", "Space Needle", "Atomium", "The Shard", "Gherkin", "Lotus Temple", "Opera House", "Forbidden City", "Kremlin", "Bran Castle"],
        12: ["Neuschwanstein Castle", "Mont Saint-Michel", "Windsor Castle", "Alhambra", "Mezquita", "Sainte-Chapelle", "Duomo di Milano", "St. Peter's Basilica", "Trevi Fountain", "Pantheon"]
    },
    "Human Anatomy": {
        11: ["Olfactory nerve", "Optic nerve", "Oculomotor nerve", "Trochlear nerve", "Trigeminal nerve", "Abducens nerve", "Facial nerve", "Vestibulocochlear nerve", "Glossopharyngeal nerve", "Vagus nerve"],
        12: ["DNA helix", "Chromosome", "Mitochondria", "Ribosome", "Endoplasmic reticulum", "Golgi apparatus", "Lysosome", "Cytoskeleton", "Cell membrane", "Nucleus"]
    }
}

def fetch_wikipedia_image(query):
    try:
        search_url = f"https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch={urllib.parse.quote(query)}&utf8=&format=json"
        req = urllib.request.Request(search_url, headers={'User-Agent': 'AlioloApp/1.0'})
        with urllib.request.urlopen(req, context=ctx) as response:
            data = json.loads(response.read())
            if not data['query']['search']: return None
            page_title = data['query']['search'][0]['title']

        img_url_req = f"https://en.wikipedia.org/w/api.php?action=query&titles={urllib.parse.quote(page_title)}&prop=pageimages&format=json&pithumbsize=800"
        req = urllib.request.Request(img_url_req, headers={'User-Agent': 'AlioloApp/1.0'})
        with urllib.request.urlopen(req, context=ctx) as response:
            data = json.loads(response.read())
            pages = data['query']['pages']
            for page_id in pages:
                if 'thumbnail' in pages[page_id]:
                    return pages[page_id]['thumbnail']['source']
    except Exception as e:
        print(f"Error fetching: {e}")
    return None

def main():
    total_created = 0
    for subject, levels in ADVANCED_DATA.items():
        subject_dir = os.path.join(CARDS_DIR, subject)
        if not os.path.exists(subject_dir): os.makedirs(subject_dir)

        print(f"\\n--- {subject} ---")
        for level, terms in levels.items():
            for term in terms:
                clean_answer = term.replace('Flag of ', '').replace('the ', '').replace('Human ', '').replace(' nerve', '')
                print(f"Fetching: {term}...", end='', flush=True)
                img_url = fetch_wikipedia_image(term)
                if img_url:
                    file_id = str(uuid.uuid4())
                    img_path = os.path.join(subject_dir, f"{file_id}.jpg")
                    json_path = os.path.join(subject_dir, f"{file_id}.json")
                    try:
                        req = urllib.request.Request(img_url, headers={'User-Agent': 'AlioloApp/1.0'})
                        with urllib.request.urlopen(req, context=ctx) as response, open(img_path, 'wb') as out_file:
                            out_file.write(response.read())
                        card_data = {
                            "id": "aliolo", "fileId": file_id, "subject": subject, "level": level,
                            "prompt": "What is this?", "answers": [clean_answer.lower(), term.lower()],
                            "imageFileName": f"{file_id}.jpg", "videoUrl": ""
                        }
                        with open(json_path, 'w') as f: json.dump(card_data, f, indent=2)
                        print(" OK!")
                        total_created += 1
                        time.sleep(0.8) # Slower to avoid 429
                    except: print(" FAILED")
                else: print(" SKIP")

    print(f"\\nCreated {total_created} advanced cards.")

if __name__ == "__main__":
    main()
