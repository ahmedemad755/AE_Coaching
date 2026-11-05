"""Import only pinned, referenced RepDB Free assets for AE Coaching in-app use.

The downloaded archive stays in build/. Never publish it as a dataset mirror.
Run: python tool/import_repdb_dataset.py --archive build/repdb-audit/upstream.zip
"""
import argparse
import collections
import hashlib
import json
from pathlib import Path, PurePosixPath
import zipfile

ROOT = Path(__file__).resolve().parents[1]
COMMIT = '66c4298af8d99b9dc397dad6699e508fb871d249'
DEST = ROOT / 'lib/assets/repdb'


def require(condition, message):
    if not condition:
        raise ValueError(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=Path, required=True)
    args = parser.parse_args()
    tree = json.loads((ROOT / 'build/repdb-audit/upstream-tree.json').read_text())
    require(tree['sha'] == COMMIT and not tree['truncated'], 'Unpinned/incomplete Git tree')
    blobs = {row['path']: row for row in tree['tree'] if row['type'] == 'blob'}
    with zipfile.ZipFile(args.archive) as archive:
        prefix = f'exercise-dataset-{COMMIT}/'

        def checked(relative):
            require(relative in blobs, f'File absent from pinned Git tree: {relative}')
            data = archive.read(prefix + relative)
            header = f'blob {len(data)}\0'.encode()
            require(hashlib.sha1(header + data).hexdigest() == blobs[relative]['sha'],
                    f'Git blob hash differs: {relative}')
            return data

        raw = checked('exercises.json')
        source = json.loads(raw)
        require(source['schema_version'] == 3, 'Unsupported upstream schema')
        exercises = source['exercises']
        require(source['count'] == len(exercises), 'Incorrect source count')
        ids = set()
        paths = set()
        shapes = collections.Counter()
        missing = collections.defaultdict(list)
        for exercise in exercises:
            identifier = exercise.get('id')
            require(isinstance(identifier, str) and identifier and identifier not in ids,
                    f'Missing/duplicate ID: {identifier}')
            ids.add(identifier)
            require(isinstance(exercise.get('name_en'), str) and exercise['name_en'].strip(),
                    f'Missing English name: {identifier}')
            for field in ('primary_muscles', 'secondary_muscles', 'instructions_en', 'tips_en'):
                value = exercise.get(field, [])
                require(isinstance(value, list) and all(isinstance(v, str) and v.strip() for v in value),
                        f'Invalid {field}: {identifier}')
                if not value:
                    missing[field].append(identifier)
            if 'equipment' in exercise:
                require(isinstance(exercise['equipment'], str) and exercise['equipment'].strip(),
                        f'Invalid equipment: {identifier}')
            else:
                missing['equipment_not_supplied'].append(identifier)
            images = exercise.get('images', {}).get('flat', {})
            require(set(images) in ({'start', 'peak'}, {'main'}), f'Unexpected free image shape: {identifier}')
            shapes['two_images' if len(images) == 2 else 'one_image'] += 1
            for image in images.values():
                parts = PurePosixPath(image).parts
                require(parts[:2] == ('images', 'flat') and '..' not in parts and image.endswith('.webp'),
                        f'Restricted/unsafe image path: {image}')
                paths.add(image)
        # Validate every permitted file before writing any application asset.
        image_bytes = {}
        for relative in sorted(paths):
            data = checked(relative)
            require(data[:4] == b'RIFF' and data[8:12] == b'WEBP', f'Invalid WebP: {relative}')
            image_bytes[relative] = data
        metadata = {p: checked(p) for p in ('LICENSE-DATA.md', 'ATTRIBUTION.md')}
        DEST.mkdir(parents=True, exist_ok=True)
        (DEST / 'exercises.json').write_bytes(raw)
        for relative, data in metadata.items():
            (DEST / relative).write_bytes(data)
        for relative, data in image_bytes.items():
            output = DEST / relative
            output.parent.mkdir(parents=True, exist_ok=True)
            output.write_bytes(data)
        source_info = {
            'repository': 'https://github.com/RepDB/exercise-dataset',
            'commit': COMMIT, 'upstreamSchema': 3,
            'attribution': 'Exercise data by RepDB (repdb.co)',
            'attributionUrl': 'https://repdb.co',
            'license': 'RepDB Free Tier License v1.0',
            'licenseFile': 'LICENSE-DATA.md',
            'catalogSha256': hashlib.sha256(raw).hexdigest(),
            'modifications': 'English source and image bytes unchanged. Arabic text is an application-local overlay.',
            'canonicalIdPrefix': 'repdb:',
            'images': {p: hashlib.sha256(v).hexdigest() for p, v in image_bytes.items()},
        }
        (DEST / 'SOURCE.json').write_text(json.dumps(source_info, indent=2) + '\n', encoding='utf-8')
        report = {
            'datasetCommit': COMMIT, 'totalImported': len(exercises), **shapes,
            'withoutUsableImages': 0, 'uniqueImages': len(paths),
            'imageBytes': sum(map(len, image_bytes.values())),
            'missingMetadata': dict(missing), 'validationFailures': [],
            'premiumAssetsImported': 0, 'sourceBytesUnchanged': True,
        }
        (ROOT / 'docs/repdb-import-report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
        print(json.dumps({k: v for k, v in report.items() if k != 'missingMetadata'}))


if __name__ == '__main__':
    main()
