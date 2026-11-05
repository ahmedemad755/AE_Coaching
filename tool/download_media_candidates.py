"""Fetch explicitly inventoried, licensed artwork candidates, never MuscleWiki media.

Development-only: downloads are unapproved candidates until visually reviewed.
No application state or runtime network behavior is changed.
"""
import concurrent.futures
import csv
import hashlib
import json
import urllib.request
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
AUDIT = ROOT / 'build/media-audit'
EVER = '446bb9a3d0c3beb6b84f7c9d77dfc8af707a2ab6'
EXTRA_KEYS = ['ever:arnold-press@1', 'guide:push-press@1', 'guide:burpee@3']


def inventory():
    rows = list(csv.DictReader((ROOT / 'tool/exercise_media_inventory.tsv').open(encoding='utf-8'), delimiter='\t'))
    catalog = json.loads((ROOT / 'lib/assets/data/exercises_catalog.json').read_text(encoding='utf-8'))['exercises']
    assert len(rows) == len({r['id'] for r in rows}) == 180
    assert {r['id'] for r in rows} == {r['id'] for r in catalog}
    return rows


def sources():
    art_revision = json.loads((AUDIT / 'open-art-commit.json').read_text())['sha']
    guide_revision = json.loads((AUDIT / 'workout-guide-commit.json').read_text())['sha']
    art = json.loads((AUDIT / 'open-art-catalogue.json').read_text(encoding='utf-8'))['exercises']
    tree_bytes = (ROOT / 'build/everkinetic-source-tree.json').read_bytes()
    ever_tree = {r['path'] for r in json.loads(tree_bytes.decode('utf-16' if tree_bytes.startswith(b'\xff\xfe') else 'utf-8-sig'))['tree']}
    guide_tree = {r['path'] for r in json.loads((AUDIT / 'workout-guide-tree.json').read_text())['tree']}
    result = {}
    for row in art:
        result['art:' + row['id']] = {
            'repo': 'AlexMollard/Open-Exercise-Art', 'revision': art_revision,
            'path': row['png']['file'], 'sha256': row['png']['sha256'],
            'author': 'Open Exercise Art / Alex Mollard',
        }
    guide_manifest = {r['slug']: r for r in json.loads((AUDIT / 'guide-manifest.json').read_text(encoding='utf-8'))}
    for key in [r['candidate'] for r in inventory()] + EXTRA_KEYS:
        base, _, explicit_frame = key.partition('@')
        frame = explicit_frame or '2'
        if key.startswith('ever:'):
            path = 'src/images-web/' + base.split(':')[1] + '-' + frame + '.png'
            assert path in ever_tree, path
            result[key] = {'repo': 'everkinetic/data', 'revision': EVER, 'path': path, 'author': 'Everkinetic / Greg Priday'}
        elif key.startswith('guide:'):
            slug = base.split(':')[1]
            path = 'packages/workout-guide/assets/' + slug + '/frame-' + frame + '.png'
            assert path in guide_tree, path
            attribution = next(f['attribution'] for f in guide_manifest[slug]['frames'] if f['index'] == int(frame))
            result[key] = {'repo': 'bryllim/workout-guide', 'revision': guide_revision, 'path': path, 'author': 'Bryl Lim / Workout Guide' + ('; Everkinetic / Greg Priday' if attribution.get('source') else ''), 'upstreamAttribution': attribution}
    return result


def download(item):
    key, source = item
    target = AUDIT / 'candidates' / (key.replace(':', '--') + '.png')
    target.parent.mkdir(exist_ok=True)
    if not target.exists():
        url = f"https://raw.githubusercontent.com/{source['repo']}/{source['revision']}/{source['path']}"
        request = urllib.request.Request(url, headers={'User-Agent': 'AE-Coaching-licensed-artwork-review'})
        with urllib.request.urlopen(request, timeout=35) as response:
            data = response.read()
        if 'sha256' in source:
            assert hashlib.sha256(data).hexdigest() == source['sha256'], key
        target.write_bytes(data)
    if 'sha256' in source:
        assert hashlib.sha256(target.read_bytes()).hexdigest() == source['sha256'], key
    return key


def sheets(rows):
    font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 13)
    for offset in range(0, len(rows), 20):
        group = rows[offset:offset + 20]
        sheet = Image.new('RGB', (1200, 1020), 'white')
        draw = ImageDraw.Draw(sheet)
        for index, row in enumerate(group):
            x, y = (index % 5) * 240, (index // 5) * 255
            source = AUDIT / 'candidates' / (row['candidate'].replace(':', '--') + '.png')
            with Image.open(source) as original:
                rgba = original.convert('RGBA')
                rgba.thumbnail((226, 202), Image.Resampling.LANCZOS)
                back = Image.new('RGB', rgba.size, '#171d2b' if row['candidate'].startswith(('art:', 'guide:')) else 'white')
                back.paste(rgba, mask=rgba.getchannel('A'))
                sheet.paste(back, (x + (240 - back.width)//2, y))
            label = row['id'][3:]
            draw.text((x + 4, y + 204), label[:30], fill='black', font=font)
            draw.text((x + 4, y + 221), label[30:], fill='black', font=font)
            draw.text((x + 4, y + 238), row['candidate'][:34], fill='black', font=font)
        sheet.save(AUDIT / f'contact-{offset//20 + 1:02}.jpg', quality=94)


if __name__ == '__main__':
    import sys
    if '--approved-only' in sys.argv:
        # Reproduction does not require the transient discovery catalogs.
        approved = json.loads((ROOT / 'tool/exercise_media_image_reviews.json').read_text(encoding='utf-8'))
        source_index = {s['key']: s for r in approved if r['status'] == 'verified' for s in r['sources']}
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            for key in pool.map(download, source_index.items()):
                print('Verified source bytes:', key, flush=True)
        raise SystemExit(0)
    rows = inventory()
    source_index = sources()
    keys = sorted({r['candidate'] for r in rows if r['candidate']} | set(EXTRA_KEYS))
    assert set(keys) <= source_index.keys(), set(keys) - source_index.keys()
    failures = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        futures = {pool.submit(download, (key, source_index[key])): key for key in keys}
        for count, future in enumerate(concurrent.futures.as_completed(futures), 1):
            try:
                future.result()
            except Exception as error:
                failures.append(futures[future])
                print('FAILED', futures[future], str(error), flush=True)
            if count % 10 == 0:
                print(f'Checked {count}/{len(keys)} candidates', flush=True)
    (AUDIT / 'candidate-sources.json').write_text(json.dumps({key: source_index[key] for key in keys}, indent=2) + '\n', encoding='utf-8')
    if failures:
        raise SystemExit(f'{len(failures)} failed downloads; rerun to retry only missing files')
    sheets([row for row in rows if row['candidate']])
    print(f'Candidate exercise rows: {sum(bool(row["candidate"]) for row in rows)}; no candidates: {sum(not row["candidate"] for row in rows)}')
