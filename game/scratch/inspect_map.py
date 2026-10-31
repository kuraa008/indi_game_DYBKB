import json

with open('scenes/Карта_6.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

for obj in data.get('objects', []):
    t = str(obj.get('type', ''))
    if any(k in t for k in ['key', 'crowbar', 'nightstand', 'dresser', 'door', 'chair', 'alarm', 'remote']):
        print(f"{obj.get('name', '')} | type={t} | pos={obj.get('position')} | meta={obj.get('meta', {})}")
