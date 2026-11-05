"""Development-only candidate discovery. Nothing here approves a mapping."""
import difflib
import json
from pathlib import Path

catalog = json.loads(Path('lib/assets/data/exercises_catalog.json').read_text(encoding='utf-8'))['exercises']
art = json.loads(Path('build/media-audit/open-art-catalogue.json').read_text(encoding='utf-8'))['exercises']
names = {item['id']: item for item in art}
for index, item in enumerate(catalog, 1):
    slug = item['name_en'].lower().replace('°', '').replace("'", '').replace(' ', '-')
    choices = difflib.get_close_matches(slug, names, n=3, cutoff=0.42)
    print(f"{index:03} {item['id'][3:]}: {' | '.join(choices)}")
