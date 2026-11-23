"""Summarize inspected public-page captures, without redistributing page text.

Run after manual matching in exercise_media_video_reviews.tsv. A URL/status or
this metadata alone does not establish a biomechanical match: retain the review.
No media, API, or runtime network access is used here.
"""
import csv
import hashlib
import json
import re
from pathlib import Path
from urllib.parse import urlsplit, urlunsplit


def canonical(url):
    value = urlsplit(url)
    return urlunsplit((value.scheme, value.netloc, value.path.rstrip('/'), '', ''))


def capture_index():
    result = {}
    audit = Path('build/media-audit')
    files = list(audit.glob('pages*.txt')) + list(audit.glob('final-pages*.txt')) + list(audit.glob('supplement-pages*.txt')) + list(audit.glob('secondary-search-*.txt'))
    for path in files:
        for block in re.split(r'-{20,}', path.read_text(encoding='utf-8')):
            header = re.search(r'([^\n]+) \((https://musclewiki\.com/(?:[a-z]{2}-[a-z]{2}/)?exercise/[^)]+)\)', block)
            if not header or not re.search(r'Source: (?:open|click)\(', block) or not re.search(r'L\d+:', block):
                continue
            if block.count('Image:') < 2 or len(block) < 1000:
                continue
            url = canonical(header[2])
            if url not in result or len(result[url]['_capture']) < len(block):
                youtube = bool(re.search(r'【\d+†(?!YouTube†)[^】]+†www\.youtube\.com】', block))
                result[url] = {
                    'url': url, 'pageTitle': header[1],
                    'reviewedOn': '2026-11-01',
                    'captureSha256': hashlib.sha256(block.encode('utf-8')).hexdigest(),
                    'demonstrationEvidence': 'exercise-specific YouTube link' if youtube else 'exercise-labeled demonstration media panels',
                    'playbackVerified': False, '_capture': block,
                }
    return result


if __name__ == '__main__':
    index = capture_index()
    rows = list(csv.DictReader(Path('tool/exercise_media_video_reviews.tsv').open(encoding='utf-8'), delimiter='\t'))
    missing = [r for r in rows if canonical(r['url']) not in index]
    Path('build/media-audit/pages-still-needed.json').write_text(json.dumps(missing, ensure_ascii=False, indent=2), encoding='utf-8')
    if missing:
        print('Actual page captures still needed:')
        for row in missing:
            print(row['id'], row['url'])
        raise SystemExit(1)
    evidence = []
    for row in rows:
        item = dict(index[canonical(row['url'])])
        item.pop('_capture')
        item.update(exerciseId=row['id'], verificationMethod='manual title/equipment/movement/variation content review', matchReview=row['match_review'])
        evidence.append(item)
    Path('docs/exercise-media-page-evidence.json').write_text(json.dumps(evidence, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'{len(evidence)} approved ID-to-page matches have actual page-content evidence; no video playback claim.')
