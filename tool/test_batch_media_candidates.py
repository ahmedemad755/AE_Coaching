"""Guard shortlist boundaries; matching is deliberately not an approval path."""
import unittest
import hashlib
import json
from pathlib import Path

from batch_media_candidates import match, shortlist


class BatchMatchingTests(unittest.TestCase):
    def result(self, name, gear, candidate, source_gear=''):
        return match({'name_en': name, 'equipment': gear},
                     {'name': candidate, 'equipment': source_gear})

    def test_reverse_grip_alias_recovers_underhand_row(self):
        result = self.result('Underhand Barbell Row', 'barbell',
                             'Reverse Grips Bent Over Barbell Rows', 'barbell')
        self.assertEqual(result['conflicts'], [])
        self.assertGreater(result['score'], 85)

    def test_equipment_and_opposite_variations_are_rejected(self):
        for name, gear, candidate, source in [
            ('Cable Fly', 'cable', 'Dumbbell Fly', 'Dumbbells'),
            ('Seated Lateral Raise', 'dumbbell', 'Standing Lateral Raise', 'dumbbell'),
            ('Incline Bench Press', 'barbell', 'Decline Bench Press', 'barbell'),
            ('Barbell Clean', 'barbell', 'Barbell Clean and Press', 'barbell'),
            ('Leg Press', 'machine', 'Leg Press Calf Raise', 'machine'),
            ('Spider Curl', 'dumbbell', 'Leg Curl', ''),
        ]:
            with self.subTest(candidate=candidate):
                self.assertTrue(self.result(name, gear, candidate, source)['conflicts'])

    def test_generic_match_still_flags_unverified_required_variation(self):
        result = self.result('Wide Grip Seated Cable Row', 'cable', 'Seated Cable Row', 'cable')
        self.assertIn('wide', result['unconfirmedNameTerms'])
        self.assertNotIn('verified', result)

    def test_verified_entries_are_excluded_and_rights_held_never_queued(self):
        catalog = [{'id': i, 'name_en': 'Reverse Lunge', 'equipment': 'bodyweight'}
                   for i in ('old', 'gap')]
        reviews = {'old': {'status': 'verified'}, 'gap': {'status': 'missing', 'review': 'Unresolved'}}
        candidates = [{'key': 'wger:999', 'name': 'Reverse Lunge',
                       'equipment': 'bodyweight', 'rightsGate': 'hold: unverified'}]
        result = shortlist(catalog, reviews, candidates)
        self.assertEqual([r['exerciseId'] for r in result], ['gap'])
        self.assertEqual(result[0]['sheetCandidates'], [])
        self.assertEqual(len(result[0]['rightsHeldCandidates']), 1)
        self.assertEqual(reviews['old'], {'status': 'verified'})

    def test_continuation_preserves_prior_approvals_and_records_all_gap_decisions(self):
        root = Path(__file__).resolve().parents[1]
        report = json.loads((root / 'docs/exercise-media-batch-review.json').read_text(encoding='utf-8'))
        manifest = json.loads((root / 'lib/assets/exercise_illustrations/manifest.json').read_text(encoding='utf-8'))
        current = {r['exerciseId']: r for r in manifest}
        preserved = report['preservedImageMappings']
        self.assertEqual(len(preserved), report['baselineImages'])
        self.assertEqual(len({r['exerciseId'] for r in preserved}), 142)
        for old in preserved:
            self.assertEqual({k: current[old['exerciseId']][k] for k in old}, old)
            self.assertEqual(hashlib.sha256((root / old['assetPath']).read_bytes()).hexdigest(), old['assetSha256'])
        self.assertEqual(hashlib.sha256((root / 'tool/exercise_media_video_reviews.tsv').read_bytes()).hexdigest(),
                         report['preservedVideoReviewsSha256'])
        self.assertEqual(len({r['exerciseId'] for r in report['reviews']}), 38)
        self.assertEqual(sum(r['result'] == 'verified' for r in report['reviews']), 2)
        for sheet in report['sheets']:
            self.assertTrue(20 <= sheet['candidatePlacements'] <= 30)
        for review in report['reviews']:
            self.assertEqual(review['result'] == 'verified', review['exerciseId'] in current)
            self.assertTrue(review['review'].strip())


if __name__ == '__main__':
    unittest.main()
