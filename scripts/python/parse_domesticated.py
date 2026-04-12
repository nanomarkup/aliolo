from bs4 import BeautifulSoup
import json
import re

with open("domesticated_animals_source.html", "r") as f:
    soup = BeautifulSoup(f, "html.parser")

results = []
# Find the first wikitable
table = soup.find("table", class_="wikitable")
if table:
    rows = table.find_all("tr")
    # First row is usually header
    for row in rows[1:]:
        cols = row.find_all("td")
        if len(cols) >= 3:
            # Species name is in 1st col, Image in 3rd (usually)
            # Let's be smart and find the image anywhere in the row if needed
            name = cols[0].get_text().strip()
            # Clean name (remove citations and parentheses)
            name = re.sub(r'\[\d+\]', '', name)
            name = name.split("(")[0].strip()
            
            img_tag = row.find("img")
            img_url = None
            if img_tag:
                img_url = img_tag.get("src")
                if img_url:
                    if img_url.startswith("//"): img_url = "https:" + img_url
                    if "/thumb/" in img_url:
                        parts = img_url.split("/")
                        img_url = "/".join(parts[:-1]).replace("/thumb/", "/")
            
            if name and img_url:
                results.append({"name": name, "url": img_url})

# Keep unique only
seen = set()
unique = []
for r in results:
    if r['name'] not in seen:
        unique.append(r)
        seen.add(r['name'])

print(json.dumps(unique[:45], indent=2))
