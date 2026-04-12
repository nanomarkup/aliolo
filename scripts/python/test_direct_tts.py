import requests
import urllib.parse
import time
import os

def download_tts(text, lang, path):
    if lang == 'zh': lang = 'zh-CN'
    url = f"https://translate.google.com/translate_tts?ie=UTF-8&q={urllib.parse.quote(text)}&tl={lang}&client=tw-ob"
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    }
    try:
        r = requests.get(url, headers=headers, timeout=10)
        if r.status_code == 200:
            with open(path, 'wb') as f:
                f.write(r.content)
            return True
        else:
            print(f"  TTS Error {r.status_code} for {text} ({lang})")
    except Exception as e:
        print(f"  TTS Exception: {e}")
    return False

# Test it
if __name__ == "__main__":
    if download_tts("Hello", "en", "test_tts.mp3"):
        print("Success! Created test_tts.mp3")
        os.remove("test_tts.mp3")
    else:
        print("Failed to create test_tts.mp3")
