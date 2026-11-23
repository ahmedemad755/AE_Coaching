"""Check the produced debug APK itself, including stale Dart/bundle detection."""
import argparse
import hashlib
import json
import re
import zipfile
from pathlib import Path
from report_exercise_media import CATALOG, CATALOG_SHA256, MEDIA, ROOT, WIDGETS, require


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apk', nargs='?', default='build/app/outputs/flutter-apk/app-debug.apk')
    args = parser.parse_args()
    manifest = json.loads((MEDIA / 'manifest.json').read_text(encoding='utf-8'))
    paths = {row['assetPath'] for row in manifest}
    video_urls = set(re.findall(r"'(https://musclewiki\.com/[^']+)'", (WIDGETS / 'exercise_video_links.dart').read_text(encoding='utf-8')))
    with zipfile.ZipFile(ROOT / args.apk) as archive:
        prefix = 'assets/flutter_assets/'
        require(hashlib.sha256(archive.read(prefix + CATALOG.relative_to(ROOT).as_posix())).hexdigest() == CATALOG_SHA256, 'APK catalog differs from original')
        for row in manifest:
            data = archive.read(prefix + row['assetPath'])
            require(hashlib.sha256(data).hexdigest() == row['assetSha256'], 'APK artwork differs: ' + row['exerciseId'])
        for path in MEDIA.iterdir():
            if path.is_file() and path.suffix != '.webp':
                require(archive.read(prefix + path.relative_to(ROOT).as_posix()) == path.read_bytes(), 'APK license/provenance is stale: ' + path.name)
        packed_images = {name.removeprefix(prefix) for name in archive.namelist() if name.startswith(prefix + 'lib/assets/exercise_illustrations/') and name.endswith('.webp')}
        require(packed_images == paths, 'APK has missing or unreviewed image assets')
        # A debug kernel stores these literal registry strings. Checking compiled
        # strings catches an old app kernel even if only the asset bundle changed.
        kernel = archive.read(prefix + 'kernel_blob.bin')
        for value in paths | video_urls:
            require(value.encode('utf-8') in kernel, 'APK Dart registry is stale: ' + value)
    print(f'APK verified: {len(manifest)} image mappings / {len(paths)} files; {len(video_urls)} distinct video URLs; exact image/license/provenance bytes and current Dart registry strings; original catalog preserved.')


if __name__ == '__main__':
    main()
