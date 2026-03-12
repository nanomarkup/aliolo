import os
import json

TRANSLATIONS = {
    "abducens": "відвідний нерв", "acacia": "акація", "acropolis of athens": "Афінський акрополь", "adductor longus": "довгий привідний м'яз", "adrenal gland": "надниркова залоза", "airbus a380": "Аеробус A380", "aircraft carrier": "авіаносець", "akashi kaikyō bridge": "Міст Акасі-Кайкьо", "akita": "акіта", "albert einstein": "Альберт Ейнштейн", "alexander the great": "Александр Македонський", "alhambra": "Альгамбра", "alligator": "алігатор", "aloe vera": "алое вера", "amethyst": "аметист", "amphibious assault ship": "десантний корабель", "amygdala": "мигдалеподібне тіло", "andromeda galaxy": "Галактика Андромеди", "angkor wat": "Ангкор-Ват", "anglerfish": "вудильник", "ant": "мураха", "aorta": "аорта", "apple": "яблуко", "archery": "стрільба з лука", "aristotle": "Арістотель", "artery": "артерія", "asteroid belt": "пояс астероїдів", "astronomer": "астроном", "atomium": "Атоміум", "aurora borealis": "північне сяйво", "avocado": "авокадо", "azalea": "азалія",
    "baobab": "баобаб", "basalt": "базальт", "baseball": "бейсбол", "basketball": "баскетбол", "bear": "ведмідь", "bee": "бджола", "beech": "бук", "beetle": "жук", "big ben": "Біг-Бен", "biceps": "біцепс", "birch": "береза", "black hole": "чорна діра", "blue whale": "синій кит", "boeing 747": "Боїнг 747", "brain": "мозок", "brainstem": "стовбур мозку", "brooklyn bridge": "Бруклінський міст", "buddha": "Будда", "butterfly": "метелик", "cactus": "кактус", "camel": "верблюд", "capillary": "капіляр", "car": "автомобіль", "castle": "замок", "cat": "кіт", "cedar": "кедр", "cerebellum": "мозочок", "cerebrum": "великий мозок", "chameleon": "хамелеон", "cheetah": "гепард", "cherry": "вишня", "chicken": "курка", "chimpanzee": "шимпанзе", "cleopatra": "Клеопатра", "colosseum": "Колізей", "comet": "комета", "copper": "мідь", "crocodile": "крокодил", "daisy": "маргаритка", "dandelion": "кульбаба", "deer": "олень", "diamond": "алмаз", "dog": "собака", "dolphin": "дельфін", "duck": "качка", "eagle": "орел", "ear": "вухо", "earth": "Земля", "eiffel tower": "Ейфелева вежа", "elephant": "слон", "eye": "око", "falcon": "сокіл", "femur": "стегнова кістка", "flamingo": "фламінго", "flower": "квітка", "frog": "жаба", "galaxy": "галактика", "giraffe": "жирафа", "gold": "золото", "gorilla": "горила", "great wall of china": "Великий китайський мур", "heart": "серце", "hippopotamus": "гіпопотам", "horse": "кінь", "human": "людина", "hummingbird": "колібрі", "hyena": "гієна", "iron": "залізо", "jaguar": "ягуар", "jellyfish": "медуза", "jupiter": "Юпітер", "kangaroo": "кенгуру", "kidney": "нирка", "koala": "коала", "ladybug": "сонечко", "leopard": "леопард", "lion": "лев", "liver": "печінка", "lizard": "ящірка", "llama": "лама", "lung": "легеня", "machu picchu": "Мачу-Пікчу", "mandible": "нижня щелепа", "maple": "клен", "mars": "Марс", "mercury": "Меркурій", "mona lisa": "Мона Ліза", "monkey": "мавпа", "moon": "Місяць", "mosquito": "комар", "mount everest": "Еверест", "mount fuji": "Фуджі", "neptune": "Нептун", "neuron": "нейрон", "nose": "ніс", "oak": "дуб", "octopus": "восьминіг", "orange": "апельсин", "orca": "косатка", "owl": "сова", "palm": "пальма", "pancreas": "підшлункова залоза", "panda": "панда", "parrot": "папуга", "peacock": "павич", "penguin": "пінгвін", "pine": "сосна", "pizza": "піца", "pluto": "Плутон", "polar bear": "білий ведмідь", "pyramid": "піраміда", "rabbit": "кріль", "rhino": "носоріг", "rose": "троянда", "saturn": "Сатурн", "scorpion": "скорпіон", "sea turtle": "морська черепаха", "shark": "акула", "sheep": "вівця", "skull": "череп", "snake": "змія", "spider": "павук", "starfish": "морська зірка", "statue of liberty": "Статуя Свободи", "stomach": "шлунок", "sun": "Сонце", "sushi": "суші", "swan": "лебідь", "taj mahal": "Тадж-Махал", "tiger": "тигр", "tooth": "зуб", "toucan": "тукан", "tulip": "тюльпан", "turtle": "черепаха", "uranus": "Уран", "venus": "Венера", "whale": "кит", "wolf": "вовк", "zebra": "зебра", "ukraine": "Україна", "flag of ukraine": "прапор України"
}

def translate_file(filepath):
    with open(filepath, 'r') as f:
        data = json.load(f)
    
    if "answers" not in data: return
    
    new_answers = []
    # 1. Process current English answers
    english_raw = ""
    for ans in data["answers"]:
        if ans.startswith("UK: "):
            english_raw = ans.replace("UK: ", "")
        elif not ans.startswith("UA: "):
            english_raw = ans
    
    if not english_raw: return

    # 2. Re-prefix English
    new_answers.append(f"UK: {english_raw}")
    
    # 3. Find Ukrainian translation
    # Use first part of semicolon string for lookup
    primary_term = english_raw.split(';')[0].strip().lower()
    
    ua_val = TRANSLATIONS.get(primary_term)
    if ua_val:
        new_answers.append(f"UA: {ua_val}")
    
    # 4. Save if changed
    if len(new_answers) > 1:
        data["answers"] = new_answers
        with open(filepath, 'w') as f:
            json.dump(data, f, indent=2)

def main():
    root = os.path.expanduser("~/.aliolo/cards")
    for path, dirs, files in os.walk(root):
        for file in files:
            if file.endswith(".json"):
                translate_file(os.path.join(path, file))

if __name__ == "__main__":
    main()
