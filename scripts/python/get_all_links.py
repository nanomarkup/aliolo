from bs4 import BeautifulSoup
import re

with open("main_blog.html", "r") as f:
    soup = BeautifulSoup(f, "html.parser")

links = []
# The list is usually in a widget or page content
# Let's search for the pattern "01.", "02." etc in links
all_as = soup.find_all("a")
for a in all_as:
    text = a.text.strip()
    if re.match(r"\d+\.", text):
        href = a.get("href")
        if href and "/category/" in href:
            links.append({"text": text, "url": href})

# Dedup and sort
seen = set()
unique_links = []
for l in links:
    if l['url'] not in seen:
        unique_links.append(l)
        seen.add(l['url'])

# Ensure order by number
unique_links.sort(key=lambda x: int(re.search(r"(\d+)\.", x['text']).group(1)))

print("\n".join([f"{l['text']}|{l['url']}" for l in unique_links]))
