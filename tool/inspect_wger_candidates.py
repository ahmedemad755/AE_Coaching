"""List individually licensed image records; does not import any image."""
import csv
import difflib
import json
import re
from pathlib import Path

records = json.loads(Path('build/media-audit/wger-exerciseinfo.json').read_text(encoding='utf-8'))['results']
inventory = list(csv.DictReader(Path('tool/exercise_media_inventory.tsv').open(encoding='utf-8'), delimiter='\t'))
catalog = {r['id']: r for r in json.loads(Path('lib/assets/data/exercises_catalog.json').read_text(encoding='utf-8'))['exercises']}
eligible = []
for record in records:
    english = [t for t in record['translations'] if t['language'] == 2]
    if record['images'] and english:
        eligible.append((english[0]['name'], record))
for row in inventory:
    if row['candidate']:
        continue
    name = catalog[row['id']]['name_en']
    ranked = sorted(eligible, key=lambda e: difflib.SequenceMatcher(None, name.lower(), e[0].lower()).ratio(), reverse=True)[:2]
    print(row['id'], '=>', ' | '.join(f"{n} [exercise {r['id']}; image " + ','.join(str(i['id']) + ' license ' + str(i['license']) for i in r['images']) + ']' for n,r in ranked))
Path('build/media-audit/wger-image-candidates.json').write_text(json.dumps([{'name':n,'record':r} for n,r in eligible], indent=2), encoding='utf-8')
