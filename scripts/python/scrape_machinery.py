import requests
from bs4 import BeautifulSoup
import json

url = "https://www.bigrentz.com/blog/construction-equipment-names"
headers = {'User-Agent': 'Mozilla/5.0'}
resp = requests.get(url, headers=headers)
soup = BeautifulSoup(resp.text, 'html.parser')

results = []
# The items are enumerated 1. NAME
# They are typically in h3 or h2 tags. Let's look for headings with "number."
headings = soup.find_all(['h2', 'h3'])
for h in headings:
    text = h.get_text().strip()
    if text and text[0].isdigit() and "." in text[:4]:
        name = text.split(".", 1)[1].strip()
        # Find the next image
        img_tag = h.find_next('img')
        if img_tag:
            img_url = img_tag.get('src') or img_tag.get('data-src')
            if img_url:
                results.append({"name": name, "url": img_url})

print(json.dumps(results, indent=2))
