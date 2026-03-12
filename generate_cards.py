import os
import json
import urllib.request
import urllib.parse
import uuid
import time
import ssl

# Bypass SSL verification issues on some Linux setups
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

CARDS_DIR = os.path.expanduser("~/.aliolo/cards")

SUBJECTS = {
    "World Landmarks": {
        1: ["Eiffel Tower", "Statue of Liberty", "Colosseum", "Great Wall of China", "Taj Mahal", "Pyramids of Giza", "Machu Picchu", "Big Ben", "Mount Rushmore", "Stonehenge"],
        2: ["Sydney Opera House", "Christ the Redeemer", "Leaning Tower of Pisa", "Acropolis of Athens", "Petra", "Burj Khalifa", "Golden Gate Bridge", "Mount Fuji", "Alhambra", "Chichen Itza"],
        3: ["Angkor Wat", "Hagia Sophia", "Moai", "St. Basil's Basilica", "Parthenon", "Potala Palace", "Mount Kilimanjaro", "Victoria Falls", "Neuschwanstein Castle", "Sagrada Familia"],
        4: ["Burj Al Arab", "Empire State Building", "CN Tower", "Space Needle", "Willis Tower", "Petronas Towers", "Taipei 101", "One World Trade Center", "Gateway Arch", "Marina Bay Sands"],
        5: ["Palace of Versailles", "Mont Saint-Michel", "Buckingham Palace", "Windsor Castle", "Tower of London", "Edinburgh Castle", "Schönbrunn Palace", "Château de Chambord", "Bran Castle", "Peles Castle"]
    },
    "Human Anatomy": {
        1: ["Human heart", "Human brain", "Human lung", "Human stomach", "Human liver", "Human kidney", "Human eye", "Human ear", "Human nose", "Human tooth"],
        2: ["Human skull", "Human rib cage", "Human pelvis", "Femur", "Humerus", "Tibia", "Fibula", "Radius bone", "Ulna", "Clavicle"],
        3: ["Biceps", "Triceps", "Quadriceps", "Hamstring", "Deltoid muscle", "Pectoralis major", "Latissimus dorsi", "Gluteus maximus", "Gastrocnemius muscle", "Trapezius"],
        4: ["Human intestine", "Pancreas", "Gallbladder", "Spleen", "Urinary bladder", "Thyroid", "Adrenal gland", "Pituitary gland", "Thymus", "Prostate"],
        5: ["Red blood cell", "White blood cell", "Neuron", "Spinal cord", "Aorta", "Vena cava", "Capillary", "Vein", "Artery", "Lymph node"]
    },
    "Famous Art": {
        1: ["Mona Lisa", "Starry Night", "The Scream", "The Kiss (Klimt)", "Girl with a Pearl Earring", "The Last Supper", "Creation of Adam", "David (Michelangelo)", "Venus de Milo", "The Thinker"],
        2: ["Guernica (picasso)", "The Persistence of Memory", "American Gothic", "A Sunday on La Grande Jatte", "The Night Watch", "The Birth of Venus", "Liberty Leading the People", "Las Meninas", "The Arnolfini Portrait", "The Garden of Earthly Delights"],
        3: ["Wanderer above the Sea of Fog", "Impression, Sunrise", "Water Lilies (Monet)", "The Great Wave off Kanagawa", "The School of Athens", "Primavera (Botticelli)", "The Hay Wain", "The Fighting Temeraire", "The Gleaners", "The Raft of the Medusa"],
        4: ["Café Terrace at Night", "Luncheon of the Boating Party", "Dance at Le moulin de la Galette", "The Swing (Renoir)", "The Card Players", "The Bathers (Cézanne)", "The Potato Eaters", "The Sower", "The Angelus", "The Gleaners"],
        5: ["Nighthawks (painting)", "The Yellow Christ", "The Red Vineyard", "Vision After the Sermon", "Where Do We Come From? What Are We? Where Are We Going?", "The Sleeping Gypsy", "The Dream (Rousseau)", "The Snake Charmer", "The Sleeping Venus", "The Bather"]
    },
    "Botany": {
        1: ["Oak tree", "Pine tree", "Maple tree", "Birch tree", "Willow tree", "Palm tree", "Apple tree", "Cherry tree", "Orange tree", "Lemon tree"],
        2: ["Rose", "Tulip", "Sunflower", "Daisy", "Lily", "Orchid", "Carnation", "Daffodil", "Dandelion", "Marigold"],
        3: ["Fern", "Moss", "Cactus", "Bamboo", "Aloe vera", "Ivy", "Venus flytrap", "Snake plant", "Spider plant", "Peace lily"],
        4: ["Tomato plant", "Potato plant", "Carrot plant", "Onion plant", "Garlic plant", "Lettuce plant", "Spinach plant", "Cabbage plant", "Broccoli plant", "Cauliflower plant"],
        5: ["Strawberry plant", "Blueberry plant", "Raspberry plant", "Blackberry plant", "Grape vine", "Watermelon plant", "Melon plant", "Pumpkin plant", "Cucumber plant", "Zucchini plant"]
    },
    "Animals": {
        1: ["Lion", "Tiger", "Elephant", "Bear", "Giraffe", "Zebra", "Hippopotamus", "Rhinoceros", "Monkey", "Gorilla"],
        2: ["Dog", "Cat", "Horse", "Cow", "Pig", "Sheep", "Goat", "Chicken", "Duck", "Turkey"],
        3: ["Eagle", "Hawk", "Owl", "Falcon", "Pigeon", "Crow", "Dove", "Sparrow", "Seagull", "Woodpecker"],
        4: ["Shark", "Whale", "Dolphin", "Penguin", "Seal", "Walrus", "Sea lion", "Manatee", "Otter", "Polar bear"],
        5: ["Snake", "Lizard", "Turtle", "Crocodile", "Alligator", "Frog", "Toad", "Salamander", "Chameleon", "Gecko"]
    },
    "Vehicles": {
        1: ["Car", "Bus", "Truck", "Motorcycle", "Bicycle", "Scooter", "Train", "Subway", "Tram", "Trolley"],
        2: ["Airplane", "Helicopter", "Helicopter", "Glider", "Hot air balloon", "Blimp", "Zeppelin", "Parachute", "Hang glider", "Kite"],
        3: ["Boat", "Ship", "Yacht", "Ferry", "Cruise ship", "Submarine", "Hovercraft", "Canoe", "Kayak", "Raft"],
        4: ["Tractor", "Bulldozer", "Excavator", "Crane", "Forklift", "Dump truck", "Cement mixer", "Garbage truck", "Fire engine", "Ambulance"],
        5: ["Police car", "Taxi", "Limousine", "Chariot", "Carriage", "Wagon", "Cart", "Sled", "Sleigh", "Snowmobile"]
    }
}

def fetch_wikipedia_image(query):
    try:
        # Search for page
        search_url = f"https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch={urllib.parse.quote(query)}&utf8=&format=json"
        req = urllib.request.Request(search_url, headers={'User-Agent': 'AlioloApp/1.0'})
        with urllib.request.urlopen(req, context=ctx) as response:
            data = json.loads(response.read())
            if not data['query']['search']: return None
            page_title = data['query']['search'][0]['title']

        # Get main image of the page
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

        print(f"\\n--- Generating Subject: {subject} ---")
        for level, terms in levels.items():
            for term in terms:
                # Use clean term for answer (e.g. 'Human heart' -> 'heart')
                clean_answer = term.replace('Human ', '').replace(' (painting)', '').replace(' (Monet)', '').replace(' (Cézanne)', '').replace(' (Rousseau)', '').replace(' (Botticelli)', '').replace(' (Klimt)', '').replace(' (picasso)', '').replace(' plant', '').replace(' tree', '').replace(' bone', '').replace(' muscle', '')
                
                # Check if we already have this card (by prompt/answer to avoid dups)
                # For simplicity, we just generate.
                
                print(f"Fetching: {term} (Level {level})...", end='', flush=True)
                img_url = fetch_wikipedia_image(term)
                
                if img_url:
                    file_id = str(uuid.uuid4())
                    img_path = os.path.join(subject_dir, f"{file_id}.jpg")
                    json_path = os.path.join(subject_dir, f"{file_id}.json")
                    
                    try:
                        # Download image
                        req = urllib.request.Request(img_url, headers={'User-Agent': 'AlioloApp/1.0'})
                        with urllib.request.urlopen(req, context=ctx) as response, open(img_path, 'wb') as out_file:
                            out_file.write(response.read())
                        
                        # Save JSON
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
                        time.sleep(0.5) # Be nice to Wikipedia
                    except Exception as e:
                        print(f" FAILED Download: {e}")
                else:
                    print(" NO IMAGE FOUND.")

    print(f"\\nGeneration Complete! Created {total_created} cards.")

if __name__ == "__main__":
    main()
