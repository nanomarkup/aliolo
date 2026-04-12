import requests
import json
import os

# Supabase Config
SB_URL = "https://mltdjjszycfmokwqsqxm.supabase.co"
SB_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
sb_headers = {"apikey": SB_KEY, "Authorization": f"Bearer {SB_KEY}"}

TABLES = [
    "pillars", "profiles", "folders", "collections", "subjects", 
    "cards", "collection_items", "user_subjects", "progress", 
    "user_friendships", "user_subscriptions", "ui_translations"
]

def fetch_table(table_name):
    print(f"Fetching {table_name}...")
    all_data = []
    offset = 0
    limit = 1000
    while True:
        url = f"{SB_URL}/rest/v1/{table_name}?offset={offset}&limit={limit}"
        res = requests.get(url, headers=sb_headers)
        if res.status_code != 200:
            print(f"  Error fetching {table_name}: {res.text}")
            break
        data = res.json()
        if not data: break
        all_data.extend(data)
        if len(data) < limit: break
        offset += limit
    return all_data

def escape_sql(val):
    if val is None: return "NULL"
    if isinstance(val, (bool)): return "1" if val else "0"
    if isinstance(val, (int, float)): return str(val)
    if isinstance(val, (dict, list)):
        return "'" + json.dumps(val).replace("'", "''") + "'"
    return "'" + str(val).replace("'", "''") + "'"

def generate_inserts(table_name, data):
    if not data: return ""
    columns = data[0].keys()
    col_str = ", ".join(columns)
    
    statements = []
    # Batch inserts for SQLite
    batch_size = 5
    for i in range(0, len(data), batch_size):
        batch = data[i:i+batch_size]
        values_list = []
        for row in batch:
            vals = [escape_sql(row.get(col)) for col in columns]
            values_list.append("(" + ", ".join(vals) + ")")
        
        statements.append(f"INSERT OR REPLACE INTO {table_name} ({col_str}) VALUES\n" + ",\n".join(values_list) + ";")
    
    return "\n\n".join(statements)

def main():
    migration_sql = "PRAGMA foreign_keys = OFF;\n\n"
    
    for table in TABLES:
        data = fetch_table(table)
        print(f"  Found {len(data)} rows.")
        migration_sql += f"-- Table: {table}\n"
        migration_sql += generate_inserts(table, data) + "\n\n"
        
    migration_sql += "PRAGMA foreign_keys = ON;"
    
    with open("scripts/sql/migration_data.sql", "w") as f:
        f.write(migration_sql)
    
    print("\nMigration SQL generated in scripts/sql/migration_data.sql")

if __name__ == "__main__":
    main()
