import urllib.request
import urllib.parse
import ssl
import json

SUPABASE_URL = "https://mltdjjszycfmokwqsqxm.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
USER_ID = "f2fb4c9c-169b-447d-b8a6-dce72c4ed5ac"

context = ssl._create_unverified_context()

def test_upload():
    bucket = "card_images"
    path = f"{USER_ID}/alphabets/test/test_image.png"
    url = f"{SUPABASE_URL}/storage/v1/object/{bucket}/{path}"
    
    # Mock image data
    data = b"fake image data"
    
    headers = {
        "apikey": SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
        "Content-Type": "image/png",
        "x-upsert": "true"
    }
    
    print(f"Uploading to: {url}")
    req = urllib.request.Request(url, headers=headers, data=data, method="POST")
    try:
        with urllib.request.urlopen(req, context=context) as response:
            print(f"Response: {response.status} {response.reason}")
            print(response.read().decode())
    except urllib.error.HTTPError as e:
        print(f"HTTP Error: {e.code} {e.reason}")
        print(e.read().decode())
    except Exception as e:
        print(f"Error: {e}")

def test_upload_non_ascii():
    bucket = "card_images"
    char = "Å"
    target_lang = "sv"
    img_filename = f"alpha_{target_lang}_{char}.png"
    quoted_filename = urllib.parse.quote(img_filename)
    path = f"{USER_ID}/alphabets/{target_lang}/{quoted_filename}"
    url = f"{SUPABASE_URL}/storage/v1/object/{bucket}/{path}"
    
    # Mock image data
    data = b"fake image data"
    
    headers = {
        "apikey": SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
        "Content-Type": "image/png",
        "x-upsert": "true"
    }
    
    print(f"Uploading non-ASCII to: {url}")
    req = urllib.request.Request(url, headers=headers, data=data, method="POST")
    try:
        with urllib.request.urlopen(req, context=context) as response:
            print(f"Response: {response.status} {response.reason}")
            print(response.read().decode())
    except urllib.error.HTTPError as e:
        print(f"HTTP Error: {e.code} {e.reason}")
        print(e.read().decode())

def test_upload_full_quote():
    bucket = "card_images"
    char = "Å"
    target_lang = "sv"
    img_filename = f"alpha_{target_lang}_{char}.png"
    path = f"{USER_ID}/alphabets/{target_lang}/{img_filename}"
    quoted_path = urllib.parse.quote(path)
    url = f"{SUPABASE_URL}/storage/v1/object/{bucket}/{quoted_path}"
    
    # Mock image data
    data = b"fake image data"
    
    headers = {
        "apikey": SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
        "Content-Type": "image/png",
        "x-upsert": "true"
    }
    
    print(f"Uploading full quote to: {url}")
    req = urllib.request.Request(url, headers=headers, data=data, method="POST")
    try:
        with urllib.request.urlopen(req, context=context) as response:
            print(f"Response: {response.status} {response.reason}")
            print(response.read().decode())
    except urllib.error.HTTPError as e:
        print(f"HTTP Error: {e.code} {e.reason}")
        print(e.read().decode())

def test_upload_hex():
    bucket = "card_images"
    char = "Å"
    target_lang = "sv"
    safe_char = f"hex_{char.encode('utf-8').hex()}"
    img_filename = f"alpha_{target_lang}_{safe_char}.png"
    path = f"{USER_ID}/alphabets/{target_lang}/{img_filename}"
    url = f"{SUPABASE_URL}/storage/v1/object/{bucket}/{path}"
    
    # Mock image data
    data = b"fake image data"
    
    headers = {
        "apikey": SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
        "Content-Type": "image/png",
        "x-upsert": "true"
    }
    
    print(f"Uploading hex to: {url}")
    req = urllib.request.Request(url, headers=headers, data=data, method="POST")
    try:
        with urllib.request.urlopen(req, context=context) as response:
            print(f"Response: {response.status} {response.reason}")
            print(response.read().decode())
    except urllib.error.HTTPError as e:
        print(f"HTTP Error: {e.code} {e.reason}")
        print(e.read().decode())

if __name__ == "__main__":
    test_upload()
    test_upload_non_ascii()
    test_upload_full_quote()
    test_upload_hex()
