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

BATCH_5_DATA = {
    "Mythology": {
        1: ["Centaur", "Minotaur", "Medusa", "Cyclops", "Pegasus"],
        2: ["Phoenix", "Sphinx", "Griffin", "Hydra", "Chimera"],
        3: ["Kraken", "Siren", "Harpy", "Satyr", "Cerberus"],
        4: ["Valkyrie", "Troll", "Goblin", "Elf", "Dwarf"],
        5: ["Dragon", "Unicorn", "Basilisk", "Kelpie", "Banshee"]
    },
    "Architectural Styles": {
        1: ["Ancient Egyptian architecture", "Ancient Greek architecture", "Ancient Roman architecture", "Gothic architecture", "Renaissance architecture"],
        2: ["Baroque architecture", "Rococo", "Neoclassical architecture", "Art Nouveau", "Art Deco"],
        3: ["Modern architecture", "Brutalist architecture", "Postmodern architecture", "Deconstructivism", "Contemporary architecture"]
    },
    "Insects": {
        1: ["Ladybug", "Honey bee", "Praying mantis", "Monarch butterfly", "Stag beetle"],
        2: ["Dragonfly", "Grasshopper", "Cricket", "Firefly", "Cicada"],
        3: ["Mosquito", "Housefly", "Bedbug", "Cockroach", "Termite"]
    },
    "World Bridges": {
        1: ["Golden Gate Bridge", "Tower Bridge", "Brooklyn Bridge", "Sydney Harbour Bridge", "Rialto Bridge"],
        2: ["Ponte Vecchio", "Charles Bridge", "Széchenyi Chain Bridge", "Millau Viaduct", "Akashi Kaikyō Bridge"],
        3: ["Forth Bridge", "Mackinac Bridge", "Verrazzano-Narrows Bridge", "Confederation Bridge", "Vasco da Gama Bridge"]
    },
    "Food & Cuisines": {
        6: ["Baklava", "Falafel", "Hummus", "Baba ghanoush", "Tabbouleh"],
        7: ["Ceviche", "Empanada", "Arepa", "Feijoada", "Pisco sour"],
        8: ["Goulash", "Schnitzel", "Pierogi", "Borscht", "Stroganoff"]
    },
    "Sports": {
        6: ["Snooker", "Darts", "Billiards", "Table tennis", "Squash"],
        7: ["Bobsleigh", "Luge", "Skeleton", "Ski jumping", "Speed skating"],
        8: ["Modern pentathlon", "Decathlon", "Heptathlon", "Triathlon", "Ironman Triathlon"]
    },
    "Historical Figures": {
        6: ["Joan of Arc", "Marco Polo", "Christopher Columbus", "Vasco da Gama", "Ferdinand Magellan"],
        7: ["Catherine the Great", "Peter the Great", "Ivan the Terrible", "Nicholas II of Russia", "Grigori Rasputin"],
        8: ["Julius Caesar", "Augustus", "Nero", "Constantine the Great", "Marcus Aurelius"]
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
    for subject, levels in BATCH_5_DATA.items():
        subject_dir = os.path.join(CARDS_DIR, subject)
        if not os.path.exists(subject_dir): os.makedirs(subject_dir)

        print(f"\\n--- {subject} ---")
        for level, terms in levels.items():
            for term in terms:
                clean_answer = term.replace(' architecture', '').replace(' of Russia', '').replace(' the Great', '').replace(' the Terrible', '').replace(' the Hun', '').replace(' Triathlon', '')
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
                        time.sleep(2.0) # Slower to avoid 429
                    except: print(" FAILED")
                else: print(" SKIP")

    print(f"\\nCreated {total_created} new cards.")

if __name__ == "__main__":
    main()
