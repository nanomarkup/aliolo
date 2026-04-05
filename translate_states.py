import requests
import json
import time

LANGS = "en,id,bg,cs,da,de,et,es,fr,ga,hr,it,lv,lt,hu,mt,nl,pl,pt,ro,sk,sl,fi,sv,tl,vi,tr,el,uk,ar,hi,zh,ja,ko".split(",")
HEADERS = {"User-Agent": "AlioloContentBot/1.0 (vitaliinoga@aliolo.com)"}

def get_wikidata_qid(name):
    url = "https://www.wikidata.org/w/api.php"
    params = {
        "action": "wbsearchentities",
        "format": "json",
        "search": name,
        "language": "en",
        "type": "item"
    }
    try:
        res = requests.get(url, params=params, headers=HEADERS)
        if res.status_code != 200:
            print(f"Error searching {name}: {res.status_code}")
            return None
        data = res.json()
        if data.get("search"):
            return data["search"][0]["id"]
    except Exception as e:
        print(f"Error searching {name}: {e}")
    return None

def get_labels(qid):
    if not qid:
        return {}
    url = "https://www.wikidata.org/w/api.php"
    params = {
        "action": "wbgetentities",
        "format": "json",
        "ids": qid,
        "props": "labels",
        "languages": "|".join(LANGS)
    }
    try:
        res = requests.get(url, params=params, headers=HEADERS)
        if res.status_code != 200:
            print(f"Error getting labels for {qid}: {res.status_code}")
            return None
        data = res.json()
        labels = {}
        if data.get("entities") and qid in data["entities"]:
            entity_labels = data["entities"][qid].get("labels", {})
            for lang in LANGS:
                if lang in entity_labels:
                    labels[lang] = entity_labels[lang]["value"]
                else:
                    if "en" in entity_labels:
                        labels[lang] = entity_labels["en"]["value"]
        return labels
    except Exception as e:
        print(f"Error getting labels for {qid}: {e}")
    return {}

def translate():
    with open('scraped_states.json', 'r') as f:
        states = json.load(f)
    
    translated_states = []
    for state in states:
        print(f"Translating {state['name']}...")
        qid = get_wikidata_qid(state['name'])
        labels = get_labels(qid)
        
        if not labels:
            labels = {lang: state['name'] for lang in LANGS}
        
        for lang in LANGS:
            if lang not in labels:
                labels[lang] = labels.get("en", state['name'])
        
        state['translations'] = labels
        translated_states.append(state)
        time.sleep(0.2)
    
    with open('translated_states.json', 'w') as f:
        json.dump(translated_states, f, indent=2)

if __name__ == "__main__":
    translate()
