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

BATCH_4_DATA = {
    "Food & Cuisines": {
        1: ["Sushi", "Pizza", "Hamburger", "Taco", "Croissant"],
        2: ["Dim Sum", "Paella", "Baklava", "Pho", "Poutine"],
        3: ["Gelato", "Ramen", "Falafel", "Pad Thai", "Bibimbap"],
        4: ["Escargot", "Ceviche", "Goulash", "Hummus", "Kimchi"],
        5: ["Mochi", "Churros", "Quiche", "Ratatouille", "Tiramisu"]
    },
    "Sports": {
        1: ["Soccer", "Basketball", "Tennis", "Baseball", "Golf"],
        2: ["Fencing", "Archery", "Cricket", "Rugby", "Ice hockey"],
        3: ["Badminton", "Volleyball", "Surfing", "Snowboarding", "Boxing"],
        4: ["Lacrosse", "Water polo", "Polo", "Bowling", "Curling"],
        5: ["Judo", "Karate", "Taekwondo", "Sumo", "Wrestling"]
    },
    "Ocean Life": {
        1: ["Great white shark", "Bottlenose dolphin", "Sea turtle", "Blue whale", "Clownfish"],
        2: ["Giant squid", "Manta ray", "Box jellyfish", "Moray eel", "Hammerhead shark"],
        3: ["Seahorse", "Starfish", "Humpback whale", "Orca", "Manatee"],
        4: ["Lionfish", "Anglerfish", "Narwhal", "Walrus", "Sea lion"],
        5: ["Brain coral", "Sea anemone", "Hermit crab", "Stingray", "Pufferfish"]
    },
    "Minerals & Elements": {
        1: ["Gold nugget", "Silver", "Copper", "Iron ore", "Diamond"],
        2: ["Quartz", "Pyrite", "Malachite", "Amethyst", "Obsidian"],
        3: ["Sulfur", "Bismuth", "Fluorite", "Graphite", "Talc"],
        4: ["Emerald", "Ruby", "Sapphire", "Topaz", "Opal"],
        5: ["Coal", "Granite", "Basalt", "Marble", "Limestone"]
    },
    "Astronomy": {
        4: ["Orion (constellation)", "Ursa Major", "Cassiopeia (constellation)", "Cygnus (constellation)", "Crux"],
        5: ["Io (moon)", "Europa (moon)", "Ganymede (moon)", "Callisto (moon)", "Titan (moon)"],
        6: ["Enceladus", "Miranda (moon)", "Triton (moon)", "Charon (moon)", "Phobos (moon)"]
    },
    "Human Anatomy": {
        13: ["Red blood cell", "White blood cell", "Platelet", "Plasma", "Hemoglobin"],
        14: ["Inner ear", "Cochlea", "Semicircular canals", "Eardrum", "Eustachian tube"],
        15: ["Taste bud", "Olfactory bulb", "Retina", "Cornea", "Optic nerve"]
    },
    "Flags of the World": {
        4: ["Flag of Belgium", "Flag of Netherlands", "Flag of Austria", "Flag of Switzerland", "Flag of Denmark"],
        5: ["Flag of Finland", "Flag of Norway", "Flag of Iceland", "Flag of Greece", "Flag of Turkey"]
    },
    "Botany": {
        11: ["Baobab", "Banyan", "Mangrove", "Cypress", "Cedar"],
        12: ["Venus flytrap", "Pitcher plant", "Sundew", "Bladderwort", "Water lily"]
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
    except:
        pass
    return None

def main():
    total_created = 0
    for subject, levels in BATCH_4_DATA.items():
        subject_dir = os.path.join(CARDS_DIR, subject)
        if not os.path.exists(subject_dir): os.makedirs(subject_dir)

        print(f"\\n--- {subject} ---")
        for level, terms in levels.items():
            for term in terms:
                clean_answer = term.replace('Flag of ', '').replace(' (constellation)', '').replace(' (moon)', '').replace(' nugget', '').replace(' ore', '')
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
                        time.sleep(1.5) # Even slower to respect Wikipedia
                    except: print(" FAILED")
                else: print(" SKIP")

    print(f"\\nCreated {total_created} new cards.")

if __name__ == "__main__":
    main()
