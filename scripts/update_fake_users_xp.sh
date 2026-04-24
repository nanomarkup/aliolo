#!/bin/bash
set -e

# Get the directory of the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_DIR="$SCRIPT_DIR/../api"
SQL_DIR="$SCRIPT_DIR/sql"
SQL_FILE="$SQL_DIR/update_fake_users_xp_$(date +%s).sql"

# Ensure SQL directory exists
mkdir -p "$SQL_DIR"

echo "Fetching fake users from remote database..."
cd "$API_DIR"

# Fetch JSON output from wrangler
OUTPUT=$(npx wrangler d1 execute aliolo-db --remote --command "SELECT id FROM profiles WHERE email LIKE 'fake_%'" --json)

if [ $? -ne 0 ]; then
  echo "Error fetching users from D1."
  exit 1
fi

echo "Processing users and generating SQL..."
python3 -c "
import sys, json, random

try:
    out = sys.stdin.read().strip()
    if not out.startswith('[') and not out.startswith('{'):
        idx1 = out.find('[')
        idx2 = out.find('{')
        if idx1 == -1: idx = idx2
        elif idx2 == -1: idx = idx1
        else: idx = min(idx1, idx2)
        if idx != -1:
            out = out[idx:]
    data = json.loads(out)
    if isinstance(data, list) and len(data) > 0 and 'results' in data[0]:
        users = data[0]['results']
    else:
        print('Unexpected JSON structure from wrangler', file=sys.stderr)
        sys.exit(1)
        
    if not users:
        print('No fake users found.', file=sys.stderr)
        sys.exit(0)
        
    num_to_update = int(len(users) * 0.7)
    selected = random.sample(users, num_to_update)
    
    updates = 0
    with open('$SQL_FILE', 'w', encoding='utf-8') as f:
        for u in selected:
            uid = u.get('id')
            if uid:
                xp = random.randint(0, 500)
                f.write(f\"UPDATE profiles SET total_xp = COALESCE(total_xp, 0) + {xp} WHERE id = '{uid}';\\n\")
                updates += 1
                
    if updates > 0:
        print(f'Generated {updates} updates (70% of {len(users)})')
    else:
        print('No valid user IDs found to update.')
        
except Exception as e:
    print(f'Error processing data: {e}', file=sys.stderr)
    sys.exit(1)
" <<< "$OUTPUT"

if [ -s "$SQL_FILE" ]; then
    echo "Applying updates to remote database..."
    npx wrangler d1 execute aliolo-db --remote --file="$SQL_FILE" -y
    echo "Cleaning up..."
    rm "$SQL_FILE"
    echo "Update complete!"
else
    echo "No updates generated. Cleaning up..."
    rm -f "$SQL_FILE"
fi
