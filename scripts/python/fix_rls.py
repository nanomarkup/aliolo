import requests

URL = "https://mltdjjszycfmokwqsqxm.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
headers = {"apikey": KEY, "Authorization": "Bearer " + KEY, "Content-Type": "application/json"}

sql = """
DROP POLICY IF EXISTS "Users can view own subscription" ON public.user_subscriptions;
CREATE POLICY "Everyone can view subscription status" 
ON public.user_subscriptions FOR SELECT 
USING (true);
"""

res = requests.post(f"{URL}/rest/v1/rpc/run_sql", headers=headers, json={"sql": sql})
if res.status_code == 200:
    print("Policy updated successfully.")
else:
    # If rpc/run_sql doesn't exist, we might have to use another way.
    # But often in these environments we have some way to run SQL.
    print(f"Failed to update policy: {res.status_code} - {res.text}")
    
    # Alternative: check if we can add is_premium column to profiles instead.
    print("Attempting to add is_premium column to profiles...")
    sql_alt = "ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_premium BOOLEAN DEFAULT FALSE;"
    res_alt = requests.post(f"{URL}/rest/v1/rpc/run_sql", headers=headers, json={"sql": sql_alt})
    if res_alt.status_code == 200:
        print("Column is_premium added.")
    else:
        print(f"Failed to add column: {res_alt.status_code} - {res_alt.text}")
