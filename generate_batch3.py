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

NEW_DATA = {
    "Musical Instruments": {
        1: ["Piano", "Guitar", "Violin", "Drums", "Flute"],
        2: ["Saxophone", "Trumpet", "Cello", "Harp", "Clarinet"],
        3: ["Accordion", "Banjo", "Harmonica", "Mandolin", "Trombone"],
        4: ["Bagpipes", "Didgeridoo", "Oboe", "Sitar", "Ukulele"],
        5: ["Xylophone", "Theremin", "Lute", "Synthesizer", "Bongos"]
    },
    "Dog Breeds": {
        1: ["Golden Retriever", "German Shepherd", "Poodle", "Bulldog", "Beagle"],
        2: ["Rottweiler", "Dachshund", "Siberian Husky", "Boxer", "Great Dane"],
        3: ["Doberman", "Chihuahua", "Shih Tzu", "Pug", "Border Collie"],
        4: ["Dalmatian", "Cocker Spaniel", "Saint Bernard", "Akita", "Bichon Frise"],
        5: ["Samoyed", "Shiba Inu", "Greyhound", "Mastiff", "Maltese dog"]
    },
    "Historical Figures": {
        1: ["Albert Einstein", "Isaac Newton", "Leonardo da Vinci", "Abraham Lincoln", "Mahatma Gandhi"],
        2: ["Marie Curie", "Charles Darwin", "Wolfgang Amadeus Mozart", "William Shakespeare", "Napoleon"],
        3: ["Nelson Mandela", "Martin Luther King Jr.", "Winston Churchill", "Queen Victoria", "George Washington"],
        4: ["Galileo Galilei", "Thomas Edison", "Nikola Tesla", "Aristotle", "Plato"],
        5: ["Alexander the Great", "Julius Caesar", "Cleopatra", "Joan of Arc", "Marco Polo"]
    },
    "Tech & Gadgets": {
        1: ["Smartphone", "Laptop", "Desktop computer", "Tablet computer", "Smartwatch"],
        2: ["Digital camera", "Headphones", "Microphone", "Game controller", "Virtual reality headset"],
        3: ["Drone", "Router", "Hard disk drive", "Motherboard", "Processor"],
        4: ["Floppy disk", "Cassette tape", "Typewriter", "Gramophone", "Rotary dial telephone"],
        5: ["Robot", "3D printer", "Smart speaker", "Electric scooter", "Solar panel"]
    },
    "World Landmarks": {
        13: ["White House", "Pentagon", "United Nations Headquarters", "Mount Saint-Michel", "Carcassonne"],
        14: ["Metropolitan Museum of Art", "British Museum", "The Louvre", "Hermitage Museum", "Uffizi Gallery"],
        15: ["Space Needle", "Flatiron Building", "Chrysler Building", "The Shard", "Taipei 101"]
    },
    "Animals": {
        11: ["Seahorse", "Starfish", "Jellyfish", "Octopus", "Squid"],
        12: ["Butterfly", "Bee", "Ladybug", "Ant", "Grasshopper"],
        13: ["Scorpion", "Spider", "Centipede", "Snail", "Slug"],
        14: ["Platypus", "Echidna", "Koala", "Kangaroo", "Wombat"],
        15: ["Toucan", "Flamingo", "Peacock", "Penguin", "Ostrich"]
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
    for subject, levels in NEW_DATA.items():
        subject_dir = os.path.join(CARDS_DIR, subject)
        if not os.path.exists(subject_dir): os.makedirs(subject_dir)

        print(f"\\n--- {subject} ---")
        for level, terms in levels.items():
            for term in terms:
                clean_answer = term.replace(' dog', '').replace(' computer', '').replace(' headset', '')
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
                        time.sleep(1.2) # Increased delay to avoid rate limit
                    except: print(" FAILED")
                else: print(" SKIP")

    print(f"\\nCreated {total_created} new cards.")

if __name__ == "__main__":
    main()
