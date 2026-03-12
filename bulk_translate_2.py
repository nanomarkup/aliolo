import os
import json

TRANSLATIONS = {
    "frontal bone": "лобова кістка", "parietal bone": "тім'яна кістка", "temporal bone": "скронева кістка", "occipital bone": "потилична кістка", "sphenoid bone": "клиноподібна кістка", "ethmoid bone": "решітчаста кістка", "maxilla": "верхня щелепа", "zygomatic bone": "вилична кістка", "nasal bone": "носова кістка", "cervical vertebrae": "шийні хребці", "thoracic vertebrae": "грудні хребці", "lumbar vertebrae": "поперекові хребці", "sacrum": "крижі", "coccyx": "куприк", "sternum": "груднина", "scapula": "лопатка", "patella": "колінна чашечка", "tarsal bones": "заплесно", "metatarsal bones": "плесно", "biceps brachii": "двоголовий м'яз плеча", "triceps brachii": "триголовий м'яз плеча", "brachialis": "плечовий м'яз", "brachioradialis": "плечопроменевий м'яз", "flexor carpi radialis": "променевий згинач зап'ястя", "palmaris longus": "довгий долонний м'яз", "flexor carpi ulnaris": "ліктьовий згинач зап'ястя", "extensor carpi radialis longus": "довгий променевий розгинач зап'ястя", "extensor carpi radialis brevis": "короткий променевий розгинач зап'ястя", "extensor digitorum": "розгинач пальців", "sartorius muscle": "кравецький м'яз", "rectus femoris": "прямий м'яз стегна", "vastus lateralis": "латеральний широкий м'яз стегна", "vastus intermedius": "проміжний широкий м'яз стегна", "gluteus medius": "середній сідничний м'яз", "gluteus minimus": "малий сідничний м'яз", "tensor fasciae latae": "м'яз-натягувач широкої фасції", "pectineus": "гребінний м'яз", "medulla oblongata": "довгастий мозок", "pons": "міст", "midbrain": "середній мозок", "thalamus": "таламус", "hypothalamus": "гіпоталамус", "hippocampus": "гіпокамп", "star night": "Зоряна ніч", "the scream": "Крик", "girl with a pearl earring": "Дівчина з перловою сережкою", "the last supper": "Таємна вечеря", "creation of adam": "Створення Адама", "david": "Давид", "venus de milo": "Венера Мілоська", "the thinker": "Мислитель", "guernica": "Герніка", "the persistence of memory": "Постійність пам'яті", "american gothic": "Американська готика", "the night watch": "Нічна варта", "the birth of venus": "Народження Венери", "liberty leading the people": "Свобода, що веде народ", "las meninas": "Меніни", "the garden of earthly delights": "Сад земних насолод", "the milkmaid": "Молочниця", "the art of painting": "Алегорія живопису", "the school of athens": "Афінська школа", "the sistine madonna": "Сікстинська Мадонна", "the transfiguration": "Преображення", "the marriage of the virgin": "Заручини Діви Марії", "les demoiselles d'avignon": "Авіньйонські діви", "the weeping woman": "Жінка, що плаче", "the old guitarist": "Старий гітарист", "centaur": "кентавр", "minotaur": "мінотавр", "medusa": "Медуза", "cyclops": "циклоп", "pegasus": "Пегас", "phoenix": "фенікс", "sphinx": "сфінкс", "griffin": "грифон", "hydra": "гідра", "chimera": "хімера", "kraken": "кракен", "siren": "сирена", "harpy": "гарпія", "satyr": "сатир", "cerberus": "Цербер", "valkyrie": "валькірія", "troll": "троль", "goblin": "гоблін", "elf": "ельф", "dwarf": "карлик", "dragon": "дракон", "unicorn": "єдиноріг", "basilisk": "василіск", "kelpie": "келпі", "banshee": "банші", "sushi": "суші", "pizza": "піца", "hamburger": "гамбургер", "taco": "тако", "croissant": "круасан", "dim sum": "дімсам", "paella": "паелья", "baklava": "баклава", "pho": "фо", "poutine": "путін", "gelato": "джелато", "ramen": "рамен", "falafel": "фалафель", "pad thai": "пад-тай", "bibimbap": "бібімбап", "escargot": "равлики", "ceviche": "севіче", "goulash": "гуляш", "hummus": "гумус", "kimchi": "кімчі", "mochi": "моті", "churros": "чуррос", "quiche": "кіш", "ratatouille": "рататуй", "tiramisu": "тірамісу", "soccer": "футбол", "basketball": "баскетбол", "tennis": "теніс", "baseball": "бейсбол", "golf": "гольф", "fencing": "фехтування", "archery": "стрільба з лука", "cricket": "крикет", "rugby": "регбі", "ice hockey": "хокей на льоду", "badminton": "бадмінтон", "volleyball": "волейбол", "surfing": "серфінг", "snowboarding": "сноубординг", "boxing": "бокс", "lacrosse": "лакрос", "water polo": "водне поло", "polo": "поло", "bowling": "боулінг", "curling": "керлінг", "judo": "дзюдо", "karate": "карате", "taekwondo": "теквондо", "sumo": "сумо", "wrestling": "боротьба", "snooker": "снукер", "darts": "дартс", "billiards": "більярд", "table tennis": "настільний футбол", "squash": "сквош", "bobsleigh": "бобслей", "luge": "санний спорт", "skeleton": "скелетон", "ski jumping": "стрибки з трампліна", "speed skating": "ковзанярський спорт", "modern pentathlon": "сучасне п'ятиборство", "decathlon": "десятиборство", "heptathlon": "семиборство", "triathlon": "тріатлон", "ironman triathlon": "тріатлон айронмен"
}

def translate_file(filepath):
    with open(filepath, 'r') as f:
        data = json.load(f)
    if "answers" not in data: return
    
    english_raw = ""
    # Check if already has UA
    if any(a.startswith("UA: ") for a in data["answers"]): return

    for ans in data["answers"]:
        if ans.startswith("UK: "): english_raw = ans.replace("UK: ", "")
        else: english_raw = ans
    
    if not english_raw: return
    primary_term = english_raw.split(';')[0].strip().lower()
    ua_val = TRANSLATIONS.get(primary_term)
    
    if ua_val:
        data["answers"] = [f"UK: {english_raw}", f"UA: {ua_val}"]
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
