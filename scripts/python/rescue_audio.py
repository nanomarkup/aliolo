import requests
import json
import os
import time
import sys
import urllib.parse

URL_BASE = "https://mltdjjszycfmokwqsqxm.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
HEADERS = {"apikey": KEY, "Authorization": f"Bearer {KEY}"}

with open("MISSING_MEDIA_REPORT.json", "r") as f:
    report = json.load(f)

def download_tts(text, lang):
    lang_map = {
        'zh': 'zh-CN',
        'ga': 'ga',
        'mt': 'mt',
        'sl': 'sl',
    }
    lang = lang_map.get(lang, lang)
    url = f"https://translate.google.com/translate_tts?ie=UTF-8&q={urllib.parse.quote(text)}&tl={lang}&client=tw-ob"
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    }
    try:
        r = requests.get(url, headers=headers, timeout=10)
        if r.status_code == 200:
            return r.content
    except: pass
    return None

def upload_file(bucket, path, data, content_type):
    upload_url = f"{URL_BASE}/storage/v1/object/{bucket}/{path}"
    res = requests.post(upload_url, headers={**HEADERS, "Content-Type": content_type}, data=data, timeout=15)
    if res.status_code in [200, 201]: return True
    if res.status_code == 400 and "Duplicate" in res.text: return True
    return False

if len(sys.argv) < 3:
    print("Usage: python3 rescue_audio.py <start_index> <end_index>")
    sys.exit(1)

start = int(sys.argv[1])
end = int(sys.argv[2])

print(f"--- RESTORING AUDIO [{start}:{end}] ---", flush=True)
items = report['card_audio'][start:end]
total = len(items)
success = 0

for i, item in enumerate(items):
    path = item['path']
    lang = item['lang']
    text = item['answer']
    
    if not text or not lang or lang == 'global': continue
    
    print(f"[{i+1}/{total}] Generating audio for {text} ({lang})...", flush=True)
    
    audio_data = download_tts(text, lang)
    if audio_data:
        if upload_file("card_audio", path, audio_data, "audio/mpeg"):
            success += 1
            print(f"  OK: {path}", flush=True)
        else:
            print(f"  UPLOAD FAILED: {path}", flush=True)
    else:
        print(f"  TTS FAILED: {text} ({lang})", flush=True)
        
    time.sleep(0.5) # Be kind to Google

print(f"Batch Done! Restored {success}/{total} audio files.", flush=True)
