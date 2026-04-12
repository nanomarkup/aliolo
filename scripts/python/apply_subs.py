import requests
import json
import random
import uuid
import datetime

URL = "https://mltdjjszycfmokwqsqxm.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
headers = {"apikey": KEY, "Authorization": "Bearer " + KEY, "Content-Type": "application/json"}

# 1. Fetch existing subscriptions to avoid duplicates
res = requests.get(f"{URL}/rest/v1/user_subscriptions?select=user_id", headers=headers)
if res.status_code != 200:
    print(f"Error fetching subs: {res.text}")
    existing_subs = set()
else:
    existing_subs = {s['user_id'] for s in res.json()}
print(f"Found {len(existing_subs)} existing subscriptions.")

# 2. Fetch fake users
res = requests.get(f"{URL}/rest/v1/profiles?select=id,email,total_xp&email=like.fake_%&order=total_xp.desc", headers=headers)
profiles = res.json()

print(f"Total fake profiles: {len(profiles)}")

# Filter out users who already have a subscription
unsubscribed_profiles = [p for p in profiles if p['id'] not in existing_subs]

# We need to maintain the original top 50, but skip those who already have a subscription.
# To be precise to the requirements: "top 50 users by XP, 80% should have the subscription".
# So out of the top 50, 40 should have it.
top_50 = profiles[:50]
rest = profiles[50:]

top_50_existing = [p for p in top_50 if p['id'] in existing_subs]
top_50_needs = [p for p in top_50 if p['id'] not in existing_subs]

target_top = int(len(top_50) * 0.8)
needed_top = target_top - len(top_50_existing)

selected_top = []
if needed_top > 0:
    selected_top = random.sample(top_50_needs, needed_top)

rest_existing = [p for p in rest if p['id'] in existing_subs]
rest_needs = [p for p in rest if p['id'] not in existing_subs]

target_rest = int(len(rest) * 0.6)
needed_rest = target_rest - len(rest_existing)

selected_rest = []
if needed_rest > 0:
    selected_rest = random.sample(rest_needs, needed_rest)

users_to_subscribe = selected_top + selected_rest

print(f"Top 50 users: {len(top_50_existing)} have sub. Adding {len(selected_top)}.")
print(f"Remaining {len(rest)} users: {len(rest_existing)} have sub. Adding {len(selected_rest)}.")
print(f"Applying new subscriptions to {len(users_to_subscribe)} users...")

subscriptions = []
now = datetime.datetime.now(datetime.timezone.utc)
expiry = now + datetime.timedelta(days=365)

for u in users_to_subscribe:
    sub = {
        "id": str(uuid.uuid4()),
        "user_id": u['id'],
        "status": "active",
        "provider": random.choice(["apple", "google"]),
        "expiry_date": expiry.isoformat(),
        "purchase_token": str(uuid.uuid4()),
        "order_id": f"ORDER_{random.randint(10000, 99999)}",
        "product_id": "premium_yearly"
    }
    subscriptions.append(sub)

# Insert in batches of 100
for i in range(0, len(subscriptions), 100):
    batch = subscriptions[i:i+100]
    res = requests.post(f"{URL}/rest/v1/user_subscriptions", headers=headers, json=batch)
    if res.status_code not in [200, 201]:
        print(f"Failed to insert batch: {res.text}")
    else:
        print(f"Inserted batch of {len(batch)} subscriptions.")

print("Done!")
