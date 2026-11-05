"""Resume missing-image discovery from cached metadata; never approve mappings.

Offline by default. --download fetches only shortlisted artwork from the three
already licensed, pinned repositories. wger metadata is ranked but held outside
the download queue pending per-image upstream rights verification. --sheets
reuses cached files and balances sheets at 20–30 candidates where possible. No app data,
approved reviews, registries or bundled assets are written by this tool.
"""
import argparse
import difflib
import hashlib
import json
import re
import textwrap
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / 'build/media-audit'
OUTPUT = CACHE / 'continuation'


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def words(value):
    value = value.lower().replace('pull-down', 'pulldown').replace('step-up', 'stepup')
    value = re.sub(r'reverse[ -]grips?', 'underhand', value)
    value = re.sub(r'dumbbells\b', 'dumbbell', value)
    value = re.sub(r'dumbell\b', 'dumbbell', value)
    value = re.sub(r'extensions\b', 'extension', value)
    value = re.sub(r'one[ -]arm', 'single arm', value)
    value = re.sub(r'one[ -]leg', 'single leg', value)
    value = re.sub(r'raises\b', 'raise', value)
    value = re.sub(r'rows\b|rowing\b', 'row', value)
    value = re.sub(r'flys\b|flies\b', 'fly', value)
    value = re.sub(r'lunges\b', 'lunge', value)
    value = re.sub(r'crunches\b', 'crunch', value)
    value = re.sub(r'curls\b', 'curl', value)
    value = re.sub(r'presses\b', 'press', value)
    value = re.sub(r'calves\b', 'calf', value)
    return set(re.findall(r'[a-z]+', value)) - {'the', 'with', 'on', 'and', 'using'}


FAMILIES = [
    ('calf', {'calf'}), ('pullover', {'pullover'}),
    ('pulldown', {'pulldown'}), ('row', {'row'}), ('fly', {'fly'}),
    ('lateral raise', {'lateral', 'raise'}), ('curl', {'curl'}),
    ('leg press', {'leg', 'press'}), ('leg extension', {'leg', 'extension'}),
    ('lunge', {'lunge'}), ('stepup', {'stepup'}), ('squat', {'squat'}),
    ('deadlift', {'deadlift'}), ('ham raise', {'ham', 'raise'}),
    ('kickback', {'kickback'}), ('hyperextension', {'hyperextension'}),
    ('crunch', {'crunch'}), ('leg raise', {'leg', 'raise'}),
    ('thruster', {'thruster'}), ('clean', {'clean'}), ('snatch', {'snatch'}),
    ('turkish', {'turkish'}), ('man maker', {'man', 'maker'}),
]
OPPOSITES = [('seated', 'standing'), ('incline', 'decline'),
             ('wide', 'narrow'), ('underhand', 'overhand'),
             ('reverse', 'forward'), ('single', 'bilateral')]
GEAR = {'barbell', 'dumbbell', 'cable', 'kettlebell', 'machine', 'bodyweight', 'band'}


def equipment(value):
    if value.strip().lower() == 'body':
        return {'bodyweight'}
    w = words(value.replace('none (bodyweight exercise)', 'bodyweight'))
    if 'cable' in w:
        w.discard('machine')
    if 'resistance' in w:
        w.add('band')
    return w & GEAR


def match(target, candidate):
    """Explain a conservative shortlist. Score is never verification evidence."""
    tw = words(target['name_en'])
    cw = words(candidate['name'] + ' ' + ' '.join(candidate.get('aliases', [])))
    family = next((tokens for _, tokens in FAMILIES if tokens <= tw), set())
    conflicts = []
    if not family or not family <= cw:
        conflicts.append('different or unspecified movement family')
    tg = equipment(target['equipment'])
    cg = equipment(candidate.get('equipment', '')) or equipment(candidate['name'])
    if tg and cg and not tg & cg:
        conflicts.append('equipment: ' + '/'.join(sorted(cg)) + ' vs ' + '/'.join(sorted(tg)))
    for a, b in OPPOSITES:
        if (a in tw and b in cw) or (b in tw and a in cw):
            conflicts.append(f'opposed variation: {a}/{b}')
    for modifier in ('rear', 'upright', 'curtsy', 'deficit', 'stretch',
                     'incline', 'decline', 'single', 'pistol', 'split',
                     'smith', 'reverse', 'nordic', 'hanging'):
        if modifier in cw and modifier not in tw:
            conflicts.append('extra variation: ' + modifier)
    if 'curl' in tw and not {'leg', 'nordic'} & tw and {'leg', 'nordic'} & cw:
        conflicts.append('leg curl is not an arm curl')
    if {'leg', 'press'} <= tw and 'calf' in cw:
        conflicts.append('calf raise is not a leg press')
    if 'pulldown' in tw and {'straight', 'arm'} <= cw and 'straight' not in tw:
        conflicts.append('straight-arm shoulder extension vs bent-elbow pulldown')
    if 'clean' in tw and 'press' in cw and 'press' not in tw:
        conflicts.append('extra overhead press after clean')
    missing = sorted(tw - cw - GEAR)
    overlap = len(tw & cw) / max(1, len(tw))
    similarity = difflib.SequenceMatcher(None, ' '.join(sorted(tw)), ' '.join(sorted(cw))).ratio()
    return {'score': round(100 * (.75 * overlap + .25 * similarity), 1),
            'conflicts': conflicts, 'unconfirmedNameTerms': missing,
            'equipmentStatus': 'match' if tg & cg else 'unknown'}


def candidates():
    # License decisions remain frozen at repository revisions already evaluated.
    result = []
    art_rev = read(CACHE / 'open-art-commit.json')['sha']
    for row in read(CACHE / 'open-art-catalogue.json')['exercises']:
        result.append({'key': 'art:' + row['id'], 'name': row['name'],
                       'aliases': row['aliases'], 'equipment': '',
                       'repo': 'AlexMollard/Open-Exercise-Art', 'revision': art_rev,
                       'path': row['png']['file'], 'sha256': row['png']['sha256'],
                       'license': 'CC BY-SA 4.0', 'rightsGate': 'pinned artwork license'})
    guide_rev = read(CACHE / 'workout-guide-commit.json')['sha']
    for row in read(CACHE / 'guide-manifest.json'):
        frame = next(f for f in row['frames'] if f['index'] == 2)
        result.append({'key': 'guide:' + row['slug'], 'name': row['name'],
                       'equipment': row['equipment'], 'aliases': [],
                       'repo': 'bryllim/workout-guide', 'revision': guide_rev,
                       'path': 'packages/workout-guide/assets/' + row['slug'] + '/frame-2.png',
                       'license': frame['attribution']['license'],
                       'rightsGate': 'pinned artwork license'})
    tree_path = ROOT / 'build/everkinetic-source-tree.json'
    data = tree_path.read_bytes()
    tree = {r['path'] for r in json.loads(data.decode(
        'utf-16' if data.startswith(b'\xff\xfe') else 'utf-8-sig'))['tree']}
    for row in read(CACHE / 'exercises.json'):
        path = 'src/images-web/' + row['name'] + '-2.png'
        if path not in tree:
            continue
        result.append({'key': 'ever:' + row['name'], 'name': row['title'],
                       'equipment': ' '.join(row.get('equipment', [])), 'aliases': [row['name']],
                       'repo': 'everkinetic/data',
                       'revision': '446bb9a3d0c3beb6b84f7c9d77dfc8af707a2ab6',
                       'path': path, 'license': 'CC BY-SA 4.0',
                       'rightsGate': 'pinned artwork license'})
    for row in read(CACHE / 'wger-exerciseinfo.json')['results']:
        en = [t for t in row['translations'] if t['language'] == 2]
        if not en or not row['images']:
            continue
        result.append({'key': 'wger:' + str(row['id']), 'name': en[0]['name'],
                       'equipment': ' '.join(e['name'] for e in row['equipment']),
                       'aliases': [a['alias'] for a in en[0]['aliases']],
                       'license': 'per-image, unverified upstream rights',
                       'rightsGate': 'hold: contributor license label alone is insufficient',
                       'images': [{k: im[k] for k in ('id', 'license', 'license_author',
                                  'license_object_url', 'license_derivative_source_url')}
                                  for im in row['images']]})
    return result


def shortlist(catalog, reviews, source_rows):
    output = []
    for target in catalog:
        if reviews[target['id']]['status'] == 'verified':
            continue
        ranked = [dict(c, **match(target, c)) for c in source_rows]
        ranked.sort(key=lambda c: (bool(c['conflicts']), -c['score'], c['key']))
        plausible = [c for c in ranked if not c['conflicts'] and c['score'] >= 45]
        licensed = [c for c in plausible if c['rightsGate'] == 'pinned artwork license']
        # Only the best two licensed candidates per unresolved exercise go to sheets.
        output.append({'exerciseId': target['id'], 'name': target['name_en'],
                       'equipment': target['equipment'],
                       'previousReview': reviews[target['id']]['review'],
                       'sheetCandidates': licensed[:2],
                       'rightsHeldCandidates': [c for c in plausible if c['key'].startswith('wger:')][:3],
                       'nearestRejected': [c for c in ranked if c['conflicts']][:2]})
    return output


def sheets(rows):
    from PIL import Image, ImageDraw, ImageFont
    font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 16)
    small = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 14)
    entries = [(r, c) for r in rows for c in r['sheetCandidates']]
    index = []
    groups = max(1, (len(entries) + 29) // 30)
    per_sheet = max(1, (len(entries) + groups - 1) // groups)
    for offset in range(0, len(entries), per_sheet):
        group = entries[offset:offset + per_sheet]
        canvas = Image.new('RGB', (1600, ((len(group)+3)//4)*370), '#eeeeee')
        draw = ImageDraw.Draw(canvas)
        for local, (row, candidate) in enumerate(group):
            number = offset + local + 1
            x, y = (local % 4) * 400, (local // 4) * 370
            path = CACHE / 'candidates' / (candidate['key'].replace(':', '--') + '.png')
            if not path.exists():
                raise FileNotFoundError(f'Run --download first: {path}')
            with Image.open(path) as original:
                rgba = original.convert('RGBA')
                rgba.thumbnail((390, 233), Image.Resampling.LANCZOS)
                bg = Image.new('RGB', rgba.size, 'white' if candidate['key'].startswith('ever:') else '#171d2b')
                bg.paste(rgba, mask=rgba.getchannel('A'))
                canvas.paste(bg, (x + (400-bg.width)//2, y))
            labels = [f'#{number} {row["exerciseId"]}',
                      'NEED ' + row['name'] + ' / ' + row['equipment'],
                      'SOURCE ' + candidate['key'] + ' / ' + (candidate['equipment'] or 'gear unknown'),
                      'CHECK ' + ', '.join(candidate['unconfirmedNameTerms']),
                      f'CC BY-SA 4.0 | score {candidate["score"]} | NOT APPROVED']
            line_y = y + 235
            for label in labels:
                for line in textwrap.wrap(label, width=48):
                    draw.text((x + 5, line_y), line, font=small if len(label) > 45 else font, fill='black')
                    line_y += 17
            index.append({'number': number, 'exerciseId': row['exerciseId'], 'candidate': candidate['key'],
                          'sheet': f'contact-{offset//per_sheet+1:02}.jpg',
                          'sourceSha256': hashlib.sha256(path.read_bytes()).hexdigest()})
        canvas.save(OUTPUT / f'contact-{offset//per_sheet+1:02}.jpg', quality=94)
    (OUTPUT / 'sheet-index.json').write_text(json.dumps(index, indent=2) + '\n', encoding='utf-8')
    return len(entries)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--download', action='store_true')
    parser.add_argument('--sheets', action='store_true')
    args = parser.parse_args()
    catalog = read(ROOT / 'lib/assets/data/exercises_catalog.json')['exercises']
    review_rows = read(ROOT / 'tool/exercise_media_image_reviews.json')
    reviews = {r['exerciseId']: r for r in review_rows}
    assert len(catalog) == len(reviews) == len(review_rows) == 180
    assert {r['id'] for r in catalog} == reviews.keys()
    rows = shortlist(catalog, reviews, candidates())
    OUTPUT.mkdir(parents=True, exist_ok=True)
    (OUTPUT / 'metadata-shortlist.json').write_text(json.dumps(rows, indent=2) + '\n', encoding='utf-8')
    if args.download:
        import concurrent.futures
        from download_media_candidates import download
        queue = {c['key']: c for r in rows for c in r['sheetCandidates']}
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            for key in pool.map(download, queue.items()):
                print('Cached candidate:', key, flush=True)
    count = sheets(rows) if args.sheets else sum(len(r['sheetCandidates']) for r in rows)
    print(f'Preserved {180-len(rows)} verified mappings; {len(rows)} gaps ranked; {count} sheet candidates.')


if __name__ == '__main__':
    main()
