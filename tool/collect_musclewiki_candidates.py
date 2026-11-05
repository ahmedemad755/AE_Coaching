"""Index public search evidence for review, never approve or generate URL slugs."""
import difflib
import json
import re
from pathlib import Path

audit = Path('build/media-audit')
pages = {}
for path in sorted(audit.glob('search-*.txt')):
    raw = path.read_text(encoding='utf-8')
    for block in re.split(r'-{20,}', raw):
        match = re.search(r'([^\n]+) \((https://musclewiki\.com/(?:[a-z]{2}-[a-z]{2}/)?exercise/[^)]+)\)', block)
        if not match:
            continue
        url = match[2].split('?')[0]
        title = re.sub(r' Exercise Guide.*| Übungsanleitung.*| Workout.*', '', match[1])
        pages[url] = {'url': url, 'title': title, 'searchFile': path.as_posix()}
(audit / 'musclewiki-candidates.json').write_text(json.dumps(list(pages.values()), indent=2) + '\n', encoding='utf-8')

def tokens(value):
    value = value.lower().replace('triceps', 'tricep').replace('flys', 'fly').replace('flyes', 'fly').replace('biceps', 'bicep')
    return set(re.findall(r'[a-z]+', value)) - {'ex', 'exercise', 'bar', 's', 'and', 'the'}

catalog = json.loads(Path('lib/assets/data/exercises_catalog.json').read_text(encoding='utf-8'))['exercises']
suggestions = []
for item in catalog:
    query = tokens(item['name_en'])
    ranked = sorted(pages.values(), key=lambda p: (2*len(query & tokens(p['title']))/(len(query)+len(tokens(p['title'])))), reverse=True)[:3]
    suggestions.append({'id': item['id'], 'candidates': ranked})
(audit / 'musclewiki-suggestions.json').write_text(json.dumps(suggestions, indent=2) + '\n', encoding='utf-8')
for index, row in enumerate(suggestions, 1):
    print(f"{index:03} {row['id'][3:]}: " + ' | '.join(p['url'].replace('https://musclewiki.com/', '') for p in row['candidates'][:2]))
