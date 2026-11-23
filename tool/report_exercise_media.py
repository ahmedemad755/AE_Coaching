"""Generate or validate the complete catalog audit using reviewed media records.

--write updates presentation registries and audit artifacts.
--check is offline/read-only and fails for dropped IDs, orphan/unlicensed files,
unreviewed URLs, changed catalog bytes, or registry/report drift.
Manual content/visual review is required separately; format checks cannot prove
that an exercise page or illustration depicts the correct biomechanics.
"""
import argparse
import codecs
import csv
import hashlib
import io
import json
import re
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / 'lib/assets/data/exercises_catalog.json'
MEDIA = ROOT / 'lib/assets/exercise_illustrations'
WIDGETS = ROOT / 'lib/features/workout/presentation/widgets'
CATALOG_SHA256 = 'ad02176478b80b5627b817ba0ca6ff588333803f806d2879b9034b153bbac9d3'
SOURCES = {
    'everkinetic/data',
    'AlexMollard/Open-Exercise-Art',
    'bryllim/workout-guide',
}
SOURCE_INVENTORY = 'Everkinetic CC BY-SA 4.0; Open Exercise Art CC BY-SA 4.0; Workout Guide CC BY-SA 4.0; wger per-image licenses/provenance evaluated'
DATE = '2026-11-01'


def require(condition, message):
    if not condition:
        raise ValueError(message)


def read_json(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def table(path):
    with path.open(encoding='utf-8', newline='') as source:
        return list(csv.DictReader(source, delimiter='\t'))


def by_id(rows, key, expected=None):
    require(len(rows) == len({row[key] for row in rows}), f'Duplicate {key}')
    result = {row[key]: row for row in rows}
    if expected is not None:
        require(set(result) == set(expected), f'Missing/extra {key}')
    return result


def validate_video(row, evidence):
    uri = urlsplit(row['url'])
    require(uri.scheme == 'https' and uri.netloc == 'musclewiki.com', 'Unexpected video destination')
    require(bool(re.fullmatch(r'/(?:[a-z]{2}-[a-z]{2}/)?exercise/[a-z0-9-]+', uri.path)), 'Not a public exercise page')
    require(not uri.query and not uri.fragment, 'Unexpected video query or fragment')
    require(len(row['match_review'].strip()) >= 40, 'Movement/equipment review missing')
    require(evidence['url'] == row['url'], 'Evidence URL differs from mapped URL')
    require(evidence['verificationMethod'] == 'manual title/equipment/movement/variation content review', 'URL has no content review')
    require(bool(re.fullmatch('[a-f0-9]{64}', evidence['captureSha256'])), 'Missing page-content evidence digest')
    require(bool(evidence['demonstrationEvidence']) and evidence['pageTitle'], 'Missing public demonstration-page evidence')
    require(evidence['matchReview'] == row['match_review'], 'Page matching notes drift')
    require(evidence['playbackVerified'] is False, 'Do not invent a playback claim')


def load_and_validate(check_runtime=True):
    require(hashlib.sha256(CATALOG.read_bytes()).hexdigest() == CATALOG_SHA256, 'Original catalog changed')
    catalog = read_json(CATALOG)['exercises']
    ids = by_id(catalog, 'id')
    require(len(ids) == 180, 'Expected unchanged 180-item catalog')
    inventory = by_id(table(ROOT / 'tool/exercise_media_inventory.tsv'), 'id', ids)
    reviews = by_id(read_json(ROOT / 'tool/exercise_media_image_reviews.json'), 'exerciseId', ids)
    manifest = by_id(read_json(MEDIA / 'manifest.json'), 'exerciseId')
    require(set(manifest) == {key for key, value in reviews.items() if value['status'] == 'verified'}, 'Unreviewed or missing image mapping')
    paths = {}
    for key, art in manifest.items():
        review = reviews[key]
        require(review['reviewedOn'] == DATE and len(review['review']) >= 35, f'Image review missing: {key}')
        require(art['review'] == review['review'] and art['sources'] == review['sources'], f'Image review/provenance drift: {key}')
        require(art['license'] == 'CC BY-SA 4.0' and art['author'] and art['changes'], f'Image attribution missing: {key}')
        require(art['sourceUrl'] == art['sources'][0]['sourceUrl'], f'Image source drift: {key}')
        for source in art['sources']:
            require(source['repo'] in SOURCES and source['license'] == 'CC BY-SA 4.0', f'Unapproved artwork source: {key}')
            require(source['author'] and re.fullmatch('[a-f0-9]{40}', source['revision']), f'Unpinned artwork: {key}')
            require(source['sourceUrl'] == f"https://github.com/{source['repo']}/blob/{source['revision']}/{source['path']}", f'Artwork source URL drift: {key}')
            require(bool(re.fullmatch('[a-f0-9]{64}', source['sha256'])), f'Artwork source digest missing: {key}')
        path = ROOT / art['assetPath']
        require(path.parent.resolve() == MEDIA.resolve() and path.suffix == '.webp' and path.is_file(), f'Artwork file missing/outside bundle: {key}')
        require(hashlib.sha256(path.read_bytes()).hexdigest() == art['assetSha256'], f'Artwork bytes changed: {key}')
        require(all(0 < dimension <= 512 for dimension in art['dimensions']), f'Unbounded artwork dimensions: {key}')
        paths[art['assetPath']] = art['assetSha256']
    require(len(set(paths.values())) == len(paths), 'Duplicate artwork files: reuse a verified asset path')
    require({p.as_posix() for p in MEDIA.glob('*.webp')} == {(ROOT / p).as_posix() for p in paths}, 'Orphan/unlicensed bundled artwork')
    for name, required in {
        'LICENSE.md': 'Attribution-ShareAlike 4.0',
        'NOTICE.md': 'without warranties',
        'Open-Exercise-Art-LICENSE.md': 'Attribution-ShareAlike 4.0',
        'Open-Exercise-Art-ATTRIBUTION.md': 'Alex Mollard',
        'Open-Exercise-Art-PROVENANCE.md': 'generated',
        'Workout-Guide-LICENSE.md': 'CC BY-SA 4.0',
        'Workout-Guide-ATTRIBUTION.md': 'Everkinetic',
    }.items():
        require(required in (MEDIA / name).read_text(encoding='utf-8'), f'Required license/credit missing: {name}')
    videos = by_id(table(ROOT / 'tool/exercise_media_video_reviews.tsv'), 'id')
    gaps = by_id(table(ROOT / 'tool/exercise_media_video_gaps.tsv'), 'id')
    require(set(videos).isdisjoint(gaps) and set(videos) | set(gaps) == set(ids), 'Every ID needs one video decision')
    evidence = by_id(read_json(ROOT / 'docs/exercise-media-page-evidence.json'), 'exerciseId', videos)
    for key, row in videos.items():
        validate_video(row, evidence[key])
    require(all(len(row['reason']) > 40 for row in gaps.values()), 'Missing specific video gap reasons')
    require(all(r['status'] in {'verified', 'missing'} and r['review'] for r in reviews.values()), 'Unreviewed image row')
    if check_runtime:
        actual_videos = dict(re.findall(r"'(ex_[a-z0-9_]+)'\s*:\s*'(https://[^']+)'", (WIDGETS / 'exercise_video_links.dart').read_text(encoding='utf-8')))
        require(actual_videos == {key: row['url'] for key, row in videos.items()}, 'Runtime video registry drift')
        source = (WIDGETS / 'exercise_illustrations.dart').read_text(encoding='utf-8')
        actual_images = dict(re.findall(r"'(ex_[a-z0-9_]+)'\s*:\s*ExerciseIllustration\(\s*assetPath:\s*'([^']+)'", source))
        require(actual_images == {key: row['assetPath'] for key, row in manifest.items()}, 'Runtime illustration registry drift')
    return catalog, inventory, reviews, manifest, videos, gaps, evidence


def artifacts(data):
    catalog, inventory, reviews, images, videos, gaps, evidence = data
    output = []
    for exercise in catalog:
        key = exercise['id']
        item, review = inventory[key], reviews[key]
        art, video = images.get(key, {}), videos.get(key, {})
        gap = gaps.get(key, {})
        output.append({
            'exercise_id': key, 'name_en': exercise['name_en'], 'name_ar': exercise['name_ar'],
            'muscle_group': exercise['muscle_group'], 'equipment': exercise['equipment'],
            'movement_pattern': item['movement_pattern'], 'variation_requirements': item['variation_requirements'],
            'audit_status': 'reviewed', 'audited_on': DATE,
            'candidate_image_sources': SOURCE_INVENTORY,
            'image_candidate': item['candidate'],
            'image_status': 'verified' if art else 'missing',
            'image_asset': art.get('assetPath', ''), 'image_source': art.get('sourceUrl', ''),
            'image_license': art.get('license', ''),
            'image_review': review['review'],
            'image_missing_reason': '' if art else review['review'],
            'video_status': 'verified page' if video else 'unverified - hidden',
            'musclewiki_page': video.get('url', ''),
            'video_candidate': video.get('url', gap.get('candidate_url', '')),
            'video_review': video.get('match_review', ''),
            'video_missing_reason': gap.get('reason', ''),
            'video_media_evidence': evidence[key]['demonstrationEvidence'] if video else '',
            'video_playback_verified': 'false',
            'verified_on': DATE if art or video else '',
        })
    stream = io.StringIO(newline='')
    writer = csv.DictWriter(stream, fieldnames=list(output[0]))
    writer.writeheader()
    writer.writerows(output)
    csv_bytes = codecs.BOM_UTF8 + stream.getvalue().encode('utf-8')
    review_bytes = (json.dumps({
        'catalogSha256': CATALOG_SHA256, 'auditedOn': DATE,
        'sourceMatching': 'Manual per-entry visual/page-content review; format checks alone do not establish matching.',
        'totals': {'audited': 180, 'verifiedIllustrations': len(images), 'missingIllustrations': 180-len(images),
                   'verifiedMuscleWikiPages': len(videos), 'missingVideoLinks': 180-len(videos),
                   'distinctIllustrationFiles': len({a['assetPath'] for a in images.values()})},
        'exercises': output,
    }, ensure_ascii=False, indent=2) + '\n').encode('utf-8')
    return csv_bytes, review_bytes


def write_videos(videos):
    path = WIDGETS / 'exercise_video_links.dart'
    original = path.read_text(encoding='utf-8')
    replacement = '  static const Map<String, String> verifiedByExerciseId = {\n'
    replacement += ''.join(f"    '{key}': '{row['url']}',\n" for key, row in videos.items())
    replacement += '  };'
    updated, count = re.subn(r'  static const Map<String, String> verifiedByExerciseId = \{.*?\n  \};', replacement, original, flags=re.S)
    require(count == 1, 'Video registry block not found uniquely')
    path.write_text(updated, encoding='utf-8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--write', action='store_true')
    mode.add_argument('--check', action='store_true')
    args = parser.parse_args()
    data = load_and_validate(check_runtime=not args.write)
    csv_bytes, review_bytes = artifacts(data)
    outputs = {ROOT / 'docs/exercise-media-coverage.csv': csv_bytes,
               ROOT / 'docs/exercise-media-review.json': review_bytes}
    if args.write:
        write_videos(data[4])
        for path, content in outputs.items():
            path.write_bytes(content)
    else:
        for path, content in outputs.items():
            require(path.read_bytes() == content, f'Stale generated report: {path.name}')
    load_and_validate()
    print(f"Validated 180/180: {len(data[3])} verified illustrations, {180-len(data[3])} missing; {len(data[4])} verified MuscleWiki pages, {180-len(data[4])} hidden. Catalog unchanged.")


if __name__ == '__main__':
    main()
