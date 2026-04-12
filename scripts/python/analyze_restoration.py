import json
import os
import requests
import re

MISSING_REPORT = "MISSING_MEDIA_REPORT.json"
TEMP_DIRS = ["temp_audio/", "temp_high_audio/", "temp_nums/", "temp_zero/"]

with open(MISSING_REPORT, "r") as f:
    report = json.load(f)

print(f"Analyzing restoration options for {len(report['card_images'])} images and {len(report['card_audio'])} audio files...")

# --- 1. Audio Mapping ---
audio_matches = []
audio_misses = []

# Pre-scan temp dirs for all available files
local_files = {}
for d in TEMP_DIRS:
    if os.path.exists(d):
        for f in os.listdir(d):
            local_files[f.lower()] = os.path.join(d, f)

for item in report['card_audio']:
    basename = os.path.basename(item['path']).lower()
    if basename in local_files:
        audio_matches.append({"item": item, "local_path": local_files[basename]})
    else:
        audio_misses.append(item)

print(f"\nAudio Restoration Summary:")
print(f"  [FOUND LOCALLY] {len(audio_matches)} files can be re-uploaded immediately.")
print(f"  [STILL MISSING] {len(audio_misses)} files have no local backup.")

# --- 2. Image Mapping ---
image_matches = []
image_misses = []

# Load data maps
try:
    with open("scraped_states.json", "r") as f:
        states = {s['name'].lower(): s['flag_url'] for s in json.load(f)}
except: states = {}

try:
    with open("domesticated_data.json", "r") as f:
        animals = {s['name'].lower(): s['url'] for s in json.load(f)}
except: animals = {}

# Known Wikipedia titles for planets
planet_wiki = {
    "mercury": "Mercury (planet)",
    "venus": "Venus",
    "earth": "Earth",
    "mars": "Mars",
    "jupiter": "Jupiter",
    "saturn": "Saturn",
    "uranus": "Uranus",
    "neptune": "Neptune",
    "ceres": "Ceres (dwarf planet)",
    "pluto": "Pluto",
    "haumea": "Haumea",
    "makemake": "Makemake",
    "eris": "Eris (dwarf planet)"
}

def get_wiki_source(answer, subject_path):
    ans = answer.lower().strip()
    if "planets" in subject_path.lower() and ans in planet_wiki:
        return planet_wiki[ans]
    if "world landmarks" in subject_path.lower():
        return answer
    if "musical instruments" in subject_path.lower():
        return answer
    return None

for item in report['card_images']:
    ans = item['answer'].lower().strip()
    # Check manual maps
    if ans in states and "flags" in item['path'].lower():
        image_matches.append({"item": item, "source_url": states[ans], "type": "flag"})
    elif ans in animals and "domesticated" in item['path'].lower():
        image_matches.append({"item": item, "source_url": animals[ans], "type": "animal"})
    else:
        # Check Wikipedia potential
        wiki_title = get_wiki_source(item['answer'], item['path'])
        if wiki_title:
            image_matches.append({"item": item, "wiki_title": wiki_title, "type": "wiki"})
        else:
            image_misses.append(item)

print(f"\nImage Restoration Summary:")
print(f"  [MAPPABLE] {len(image_matches)} images can likely be re-downloaded from source.")
print(f"  [STILL MISSING] {len(image_misses)} images have unknown sources.")

# Save restoration plan
restoration_plan = {
    "audio_to_upload": audio_matches,
    "images_to_download": image_matches
}

with open("RESTORATION_PLAN.json", "w") as f:
    json.dump(restoration_plan, f, indent=2)

print("\nRestoration plan saved to RESTORATION_PLAN.json")
