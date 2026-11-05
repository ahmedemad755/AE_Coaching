"""Rebuild explicitly reviewed artwork from local source files; no network/data cleanup.

Source-byte hashes freeze the visual review. Pillow is a development tool only.
"""
import hashlib
import json
import shutil
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
AUDIT = ROOT / 'build/media-audit'
DESTINATION = ROOT / 'lib/assets/exercise_illustrations'
LICENSE_URL = 'https://creativecommons.org/licenses/by-sa/4.0/'
WIDGETS = ROOT / 'lib/features/workout/presentation/widgets'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def dart_string(value):
    return "'" + value.replace('\\', '\\\\').replace("'", "\\'").replace('$', r'\$').replace('\n', r'\n') + "'"


def write_registry(manifest):
    path = WIDGETS / 'exercise_illustrations.dart'
    prefix = path.read_text(encoding='utf-8').split('class ExerciseIllustrations {')[0]
    lines = [prefix.rstrip(), '', 'class ExerciseIllustrations {',
             '  const ExerciseIllustrations._();', '',
             "  static const licenseAsset = 'lib/assets/exercise_illustrations/LICENSE.md';",
             "  static const changes = 'Resized and converted from PNG to WebP; no movement changes.';",
             '  // Generated from explicitly reviewed, hashed sources. Never match by name.',
             '  static const Map<String, ExerciseIllustration> verifiedByExerciseId = {']
    for item in manifest:
        lines.append(f"    {dart_string(item['exerciseId'])}: ExerciseIllustration(")
        for key in ['assetPath', 'author', 'sourceUrl', 'license', 'changes']:
            lines.append(f"      {key}: {dart_string(item[key])},")
        lines.append('    ),')
    lines += ['  };', '', '  static ExerciseIllustration? forExercise(ExerciseLibraryItem exercise) =>',
              '      exercise.source == ExerciseLibraryItemSource.builtIn',
              '      ? verifiedByExerciseId[exercise.id]', '      : null;', '}', '']
    path.write_text('\n'.join(lines), encoding='utf-8')


def prepare():
    reviews = json.loads((ROOT / 'tool/exercise_media_image_reviews.json').read_text(encoding='utf-8'))
    catalog_path = ROOT / 'lib/assets/data/exercises_catalog.json'
    catalog = json.loads(catalog_path.read_text(encoding='utf-8'))['exercises']
    assert len(reviews) == len({r['exerciseId'] for r in reviews}) == 180
    assert {r['exerciseId'] for r in reviews} == {r['id'] for r in catalog}
    assert digest(catalog_path.read_bytes()) == 'ad02176478b80b5627b817ba0ca6ff588333803f806d2879b9034b153bbac9d3'
    DESTINATION.mkdir(exist_ok=True)
    baseline = AUDIT / 'baseline'
    baseline.mkdir(exist_ok=True)
    for original in [DESTINATION / 'manifest.json', WIDGETS / 'exercise_illustrations.dart',
                     WIDGETS / 'exercise_video_links.dart', ROOT / 'docs/exercise-media-coverage.csv']:
        backup = baseline / original.name
        if original.exists() and not backup.exists():
            shutil.copyfile(original, backup)
    manifest, assets = [], {}
    for review in reviews:
        if review['status'] != 'verified':
            continue
        frames, provenance = [], []
        for source in review['sources']:
            assert source['license'] == 'CC BY-SA 4.0'
            path = AUDIT / 'candidates' / (source['key'].replace(':', '--') + '.png')
            assert digest(path.read_bytes()) == source['sha256'], source['key']
            with Image.open(path) as original:
                rgba = original.convert('RGBA')
                background = 'white' if source['repo'] == 'everkinetic/data' else '#171d2b'
                flattened = Image.new('RGB', rgba.size, background)
                flattened.paste(rgba, mask=rgba.getchannel('A'))
                frames.append(flattened)
            provenance.append(source)
        if len(frames) == 1:
            combined = frames[0]
        else:
            combined = Image.new('RGB', (512, 384), background)
            slot_width = 512 // len(frames)
            for index, frame in enumerate(frames):
                frame.thumbnail((slot_width - 8, 376), Image.Resampling.LANCZOS)
                combined.paste(frame, (index * slot_width + (slot_width - frame.width)//2,
                                       (384 - frame.height)//2))
        combined.thumbnail((512, 512), Image.Resampling.LANCZOS)
        identity = tuple((s['sha256'], s['repo']) for s in provenance)
        asset_path = assets.setdefault(identity, f"lib/assets/exercise_illustrations/{review['exerciseId']}.webp")
        target = ROOT / asset_path
        combined.save(target, 'WEBP', quality=88, method=6)
        authors = '; '.join(dict.fromkeys(s['author'] for s in provenance))
        changes = 'Resized and converted from PNG to WebP; no movement changes.'
        if any(s['repo'] != 'everkinetic/data' for s in provenance):
            changes = 'Transparency composited on charcoal, resized and converted to WebP; no pose changes.'
        if len(frames) > 1:
            changes += ' Two complete source frames arranged side by side.'
        manifest.append({
            'exerciseId': review['exerciseId'], 'assetPath': asset_path,
            'sourceUrl': provenance[0]['sourceUrl'], 'author': authors,
            'license': 'CC BY-SA 4.0', 'licenseUrl': LICENSE_URL,
            'sourceCommit': provenance[0]['revision'], 'sourceSha256': provenance[0]['sha256'],
            'assetSha256': digest(target.read_bytes()), 'dimensions': list(combined.size),
            'reviewedOn': review['reviewedOn'], 'review': review['review'],
            'changes': changes, 'sources': provenance,
        })
    (DESTINATION / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    for original, name in [
        ('open-art-ATTRIBUTION.md', 'Open-Exercise-Art-ATTRIBUTION.md'),
        ('open-art-PROVENANCE.md', 'Open-Exercise-Art-PROVENANCE.md'),
        ('open-art-LICENSE-ARTWORK.md', 'Open-Exercise-Art-LICENSE.md'),
        ('guide-ATTRIBUTION.md', 'Workout-Guide-ATTRIBUTION.md'),
        ('guide-LICENSE-ASSETS', 'Workout-Guide-LICENSE.md'),
    ]:
        if (AUDIT / original).exists():
            shutil.copyfile(AUDIT / original, DESTINATION / name)
        else:
            assert (DESTINATION / name).exists(), 'Retained source credit missing: ' + name
    notice = [
        '# Exercise artwork attribution', '',
        'All redistributed artwork and adaptations remain under CC BY-SA 4.0.',
        LICENSE_URL, 'Full legal code: LICENSE.md. Provided without warranties.',
        'No endorsement is implied. The app code and original catalog were not sourced from these datasets.', '',
        '## Sources', '',
        'Everkinetic / Greg Priday: https://github.com/everkinetic/data',
        'Open Exercise Art / Alex Mollard: https://github.com/AlexMollard/Open-Exercise-Art',
        'Workout Guide / Bryl Lim: https://github.com/bryllim/workout-guide', '',
        'Open Exercise Art was AI-generated for Ironvellum and reviewed by its maintainer. Its visual references are Everkinetic / Greg Priday and Workout Guide / Bryl Lim. Upstream attribution and provenance are bundled alongside this notice.',
        'Workout Guide includes Everkinetic adaptations. Its per-frame upstream attribution, original source links and modification history are retained in manifest.json.', '',
        'AE Coaching changes: bounded resizing and WebP conversion; white contour assets composited on charcoal for contrast in both themes. Three entries combine two complete source frames. No poses, grips or equipment were redrawn.',
        'No MuscleWiki media or wger images are redistributed.', '',
    ]
    for item in manifest:
        notice += [f"## {item['exerciseId']}", item['author'], item['assetPath'], item['review'], item['changes']]
        for source in item['sources']:
            notice.append(source['sourceUrl'])
            if source.get('upstreamAttribution', {}).get('source'):
                notice.append('Retained upstream attribution: ' + json.dumps(source['upstreamAttribution']['source'], ensure_ascii=False))
        notice.append('')
    (DESTINATION / 'NOTICE.md').write_text('\n'.join(notice) + '\n', encoding='utf-8')
    write_registry(manifest)
    original = json.loads((baseline / 'manifest.json').read_text(encoding='utf-8'))
    old_hashes = {r['exerciseId']: r['assetSha256'] for r in original}
    assert all(r['assetSha256'] == old_hashes[r['exerciseId']] for r in manifest if r['exerciseId'] in old_hashes), 'Previously verified image bytes changed'
    print(f"Prepared {len(manifest)} mappings / {len(assets)} distinct files; {sum((ROOT / p).stat().st_size for p in assets.values())} bytes. Original five hashes preserved.")


if __name__ == '__main__':
    import sys
    if '--registry-only' in sys.argv:
        write_registry(json.loads((DESTINATION / 'manifest.json').read_text(encoding='utf-8')))
    else:
        prepare()
