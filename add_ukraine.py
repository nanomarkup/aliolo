import os
import json
import urllib.request
import urllib.parse
import uuid
import ssl

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

CARDS_DIR = os.path.expanduser("~/.aliolo/cards/Flags of the World")

def main():
    if not os.path.exists(CARDS_DIR): os.makedirs(CARDS_DIR)
    
    query = "Flag of Ukraine"
    search_url = f"https://en.wikipedia.org/w/api.php?action=query&titles={urllib.parse.quote(query)}&prop=pageimages&format=json&pithumbsize=800"
    
    print(f"Fetching: {query}...")
    req = urllib.request.Request(search_url, headers={'User-Agent': 'AlioloApp/1.0'})
    with urllib.request.urlopen(req, context=ctx) as response:
        data = json.loads(response.read())
        pages = data['query']['pages']
        img_url = None
        for page_id in pages:
            if 'thumbnail' in pages[page_id]:
                img_url = pages[page_id]['thumbnail']['source']
        
        if img_url:
            file_id = str(uuid.uuid4())
            img_path = os.path.join(CARDS_DIR, f"{file_id}.jpg")
            json_path = os.path.join(CARDS_DIR, f"{file_id}.json")
            
            # Download
            req_img = urllib.request.Request(img_url, headers={'User-Agent': 'AlioloApp/1.0'})
            with urllib.request.urlopen(req_img, context=ctx) as img_resp, open(img_path, 'wb') as out_f:
                out_file_content = img_resp.read()
                out_f.write(out_file_content)
            
            # Save JSON
            card_data = {
                "id": "aliolo",
                "fileId": file_id,
                "subject": "Flags of the World",
                "level": 1,
                "prompt": "What is this?",
                "answers": ["ukraine", "flag of ukraine"],
                "imageFileName": f"{file_id}.jpg",
                "videoUrl": ""
            }
            with open(json_path, 'w') as f:
                json.dump(card_data, f, indent=2)
            print(f"Successfully created Ukraine flag card! ID: {file_id}")
        else:
            print("Failed to find image for Ukraine flag.")

if __name__ == "__main__":
    main()
