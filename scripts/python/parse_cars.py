from bs4 import BeautifulSoup
import json
import re

with open("cars_source.html", "r") as f:
    soup = BeautifulSoup(f, "html.parser")

results = []
# The items are enumerated like #1. NAME
# Looking at the HTML, they might be in h2 or strong tags.
# Common pattern: <span id="...">#1. Sedan</span> or similar.
all_text = soup.get_text()
headings = soup.find_all(['h2', 'h3', 'h4', 'strong'])

count = 0
for h in headings:
    text = h.get_text().strip()
    if re.match(r"^#\d+\.", text):
        count += 1
        name = text.split(".", 1)[1].strip()
        
        # Find next image
        img = h.find_next("img")
        img_url = None
        if img:
            img_url = img.get("data-lazy-src") or img.get("data-src") or img.get("src")
            # Filter out generic icons or small logos
            if img_url and ("wp-content/uploads" in img_url or "i0.wp.com" in img_url):
                # Clean up i0.wp.com wrapper if present
                if "i0.wp.com/" in img_url:
                    img_url = "https://" + img_url.split("i0.wp.com/")[1].split("?")[0]
                
                results.append({"name": name, "url": img_url})

# If headings didn't work, try span with ID
if not results:
    spans = soup.find_all("span")
    for s in spans:
        text = s.get_text().strip()
        if re.match(r"^#\d+\.", text):
            name = text.split(".", 1)[1].strip()
            img = s.find_next("img")
            if img:
                img_url = img.get("data-lazy-src") or img.get("data-src") or img.get("src")
                if img_url and ("wp-content/uploads" in img_url or "i0.wp.com" in img_url):
                    if "i0.wp.com/" in img_url:
                        img_url = "https://" + img_url.split("i0.wp.com/")[1].split("?")[0]
                    results.append({"name": name, "url": img_url})

print(json.dumps(results[:30], indent=2))
