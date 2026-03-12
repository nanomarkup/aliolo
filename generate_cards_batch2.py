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

SUBJECTS = {
    "World Landmarks": {
        6: ["Empire State Building", "Statue of Zeus at Olympia", "Temple of Artemis", "Mausoleum at Halicarnassus", "Colossus of Rhodes", "Lighthouse of Alexandria", "Hanging Gardens of Babylon", "Panama Canal", "Suez Canal", "Chhatrapati Shivaji Terminus"],
        7: ["Monticello", "University of Virginia", "Independence Hall", "Everglades National Park", "Mammoth Cave National Park", "Olympic National Park", "Redwood National Park", "Yosemite National Park", "Yellowstone National Park", "Grand Canyon"],
        8: ["Alhambra", "Generalife", "Albayzín", "Burj Khalifa", "The Shard", "The Gherkin", "One World Trade Center", "Willis Tower", "Trump International Hotel and Tower (Chicago)", "Shanghai Tower"],
        9: ["Petronas Towers", "Taipei 101", "International Commerce Centre", "Lotte World Tower", "Makkah Royal Clock Tower", "Abraj Al-Bait Towers", "Guangzhou IFC", "KK100", "China Zun", "Ping An Finance Center"],
        10: ["Golden Gate Bridge", "Brooklyn Bridge", "Tower Bridge", "Sydney Harbour Bridge", "Millau Viaduct", "Akashi Kaikyō Bridge", "Ponte Vecchio", "Rialto Bridge", "Charles Bridge", "Chain Bridge (Budapest)"]
    },
    "Human Anatomy": {
        6: ["Frontal bone", "Parietal bone", "Temporal bone", "Occipital bone", "Sphenoid bone", "Ethmoid bone", "Maxilla", "Mandible", "Zygomatic bone", "Nasal bone"],
        7: ["Cervical vertebrae", "Thoracic vertebrae", "Lumbar vertebrae", "Sacrum", "Coccyx", "Sternum", "Scapula", "Patella", "Tarsal bones", "Metatarsal bones"],
        8: ["Biceps brachii", "Triceps brachii", "Brachialis", "Brachioradialis", "Flexor carpi radialis", "Palmaris longus", "Flexor carpi ulnaris", "Extensor carpi radialis longus", "Extensor carpi radialis brevis", "Extensor digitorum"],
        9: ["Sartorius muscle", "Rectus femoris", "Vastus lateralis", "Vastis medialis", "Vastus intermedius", "Gluteus medius", "Gluteus minimus", "Tensor fasciae latae", "Pectineus", "Adductor longus"],
        10: ["Cerebrum", "Cerebellum", "Brainstem", "Medulla oblongata", "Pons", "Midbrain", "Thalamus", "Hypothalamus", "Hippocampus", "Amygdala"]
    },
    "Famous Art": {
        6: ["The Night Watch", "The Milkmaid (Vermeer)", "The Astronomer (Vermeer)", "The Geographer (Vermeer)", "View of Delft", "The Art of Painting", "The Little Street", "Mistress and Maid", "Girl with a Red Hat", "A Lady Writing a Letter"],
        7: ["Las Meninas", "The Surrender of Breda", "The Spinners (Velázquez)", "The Rokeby Venus", "The Feast of Bacchus (Velázquez)", "Portrait of Innocent X", "The Water Seller of Seville", "Old Woman Frying Eggs", "Christ in the House of Martha and Mary", "The Triumph of Bacchus"],
        8: ["The Garden of Earthly Delights", "The Haywain Triptych", "The Last Judgment (Bosch)", "The Temptation of St. Anthony (Bosch)", "The Seven Deadly Sins and the Four Last Things", "The Conjurer (Bosch)", "Death and the Miser", "The Wayfarer (Bosch)", "The Stone Operation", "The Extraction of the Stone of Madness"],
        9: ["The School of Athens", "The Sistine Madonna", "The Transfiguration (Raphael)", "The Marriage of the Virgin (Raphael)", "The Entombment (Raphael)", "The Triumph of Galatea", "Saint George and the Dragon (Raphael)", "Portrait of Baldassare Castiglione", "The Parnassus", "The Liberation of Saint Peter"],
        10: ["Guernica (painting)", "Les Demoiselles d'Avignon", "The Weeping Woman", "The Old Guitarist", "Girl before a Mirror", "Three Musicians", "Jeune Fille Devant un Miroir", "Le Rêve (Picasso)", "Don Quixote (Picasso)", "Chicago Picasso"]
    },
    "Botany": {
        6: ["Avocado", "Banana", "Coconut", "Date palm", "Fig", "Guava", "Kiwi fruit", "Mango", "Papaya", "Pineapple"],
        7: ["Asparagus", "Artichoke", "Bamboo shoot", "Bean sprout", "Beetroot", "Brussels sprout", "Celery", "Chard", "Eggplant", "Okra"],
        8: ["Basil", "Coriander", "Dill", "Mint", "Oregano", "Parsley", "Rosemary", "Sage", "Thyme", "Lavender"],
        9: ["Azalea", "Begonia", "Bougainvillea", "Camellia", "Chrysanthemum", "Gardenia", "Hibiscus", "Hydrangea", "Jasmine", "Magnolia"],
        10: ["Acacia", "Baobab", "Banyan", "Cedar", "Cypress", "Eucalyptus", "Mahogany", "Mangrove", "Redwood", "Sequoia"]
    },
    "Animals": {
        6: ["Cheetah", "Leopard", "Jaguar", "Snow leopard", "Clouded leopard", "Cougar", "Lynx", "Bobcat", "Serval", "Ocelot"],
        7: ["Red panda", "Giant panda", "Koala", "Kangaroo", "Wallaby", "Wombat", "Tasmanian devil", "Platypus", "Echidna", "Opossum"],
        8: ["Bald eagle", "Golden eagle", "Peregrine falcon", "Osprey", "Barn owl", "Great horned owl", "Snowy owl", "Screech owl", "Barred owl", "Burrowing owl"],
        9: ["Komodo dragon", "King cobra", "Black mamba", "Green anaconda", "Reticulated python", "Burmese python", "Gila monster", "Galápagos tortoise", "Leatherback sea turtle", "Nile crocodile"],
        10: ["Blue whale", "Humpback whale", "Orca", "Great white shark", "Hammerhead shark", "Whale shark", "Manta ray", "Stingray", "Giant squid", "Colossal squid"]
    },
    "Vehicles": {
        6: ["Tractor-unit", "Semi-trailer", "Flatbed truck", "Box truck", "Tank truck", "Refrigerated truck", "Dump truck", "Concrete mixer", "Tow truck", "Car carrier trailer"],
        7: ["Steam locomotive", "Diesel locomotive", "Electric locomotive", "High-speed rail", "Maglev", "Monorail", "Funicular", "Cable car", "Cog railway", "Light rail"],
        8: ["Aircraft carrier", "Battleship", "Cruiser", "Destroyer", "Frigate", "Corvette", "Submarine", "Minehunter", "Patrol boat", "Amphibious assault ship"],
        9: ["Cessna 172", "Boeing 747", "Airbus A380", "Concorde", "Space Shuttle", "Saturn V", "Falcon 9", "Soyuz (spacecraft)", "International Space Station", "Hubble Space Telescope"],
        10: ["Lunar Roving Vehicle", "Mars rover", "Curiosity (rover)", "Perseverance (rover)", "Sojourner (rover)", "Opportunity (rover)", "Spirit (rover)", "Voyager 1", "Voyager 2", "New Horizons"]
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
        print(f"Error fetching image for {query}: {e}")
    return None

def main():
    if not os.path.exists(CARDS_DIR):
        os.makedirs(CARDS_DIR)

    total_created = 0

    for subject, levels in SUBJECTS.items():
        subject_dir = os.path.join(CARDS_DIR, subject)
        if not os.path.exists(subject_dir):
            os.makedirs(subject_dir)

        print(f"\\n--- Generating Subject: {subject} (Levels 6-10) ---")
        for level, terms in levels.items():
            for term in terms:
                clean_answer = term.replace('Human ', '').replace(' (painting)', '').replace(' (Vermeer)', '').replace(' (Velázquez)', '').replace(' (Bosch)', '').replace(' (Raphael)', '').replace(' (Picasso)', '').replace(' muscle', '').replace(' bone', '').replace(' plant', '').replace(' tree', '')
                
                print(f"Fetching: {term} (Level {level})...", end='', flush=True)
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
                            "id": "aliolo",
                            "fileId": file_id,
                            "subject": subject,
                            "level": level,
                            "prompt": f"What is this?",
                            "answers": [clean_answer.lower(), term.lower()],
                            "imageFileName": f"{file_id}.jpg",
                            "videoUrl": ""
                        }
                        with open(json_path, 'w') as f:
                            json.dump(card_data, f, indent=2)
                        
                        print(" OK!")
                        total_created += 1
                        time.sleep(0.5)
                    except Exception as e:
                        print(f" FAILED Download: {e}")
                else:
                    print(" NO IMAGE FOUND.")

    print(f"\\nGeneration Complete! Created {total_created} new cards.")

if __name__ == "__main__":
    main()
