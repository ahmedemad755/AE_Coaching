"""Adversarial checks for the offline inventory validator (standard library)."""
import copy
import unittest
import report_exercise_media as media


class MediaValidationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = media.load_and_validate()

    def test_full_catalog_and_generated_reports(self):
        expected_csv, expected_review = media.artifacts(self.data)
        self.assertEqual((media.ROOT / 'docs/exercise-media-coverage.csv').read_bytes(), expected_csv)
        self.assertEqual((media.ROOT / 'docs/exercise-media-review.json').read_bytes(), expected_review)

    def test_duplicate_and_missing_ids_fail(self):
        with self.assertRaisesRegex(ValueError, 'Duplicate'):
            media.by_id([{'id':'a'}, {'id':'a'}], 'id')
        with self.assertRaisesRegex(ValueError, 'Missing/extra'):
            media.by_id([{'id':'a'}], 'id', {'a','b'})

    def test_url_syntax_cannot_replace_page_content_review(self):
        row = next(iter(self.data[4].values()))
        evidence = copy.deepcopy(self.data[6][row['id']])
        evidence['verificationMethod'] = 'URL format only'
        with self.assertRaisesRegex(ValueError, 'no content review'):
            media.validate_video(row, evidence)

    def test_changed_destination_and_false_playback_claim_fail(self):
        row = next(iter(self.data[4].values()))
        evidence = copy.deepcopy(self.data[6][row['id']])
        evidence['url'] = 'https://musclewiki.com/exercise/unreviewed-example'
        with self.assertRaisesRegex(ValueError, 'differs'):
            media.validate_video(row, evidence)
        evidence['url'] = row['url']
        evidence['playbackVerified'] = True
        with self.assertRaisesRegex(ValueError, 'playback claim'):
            media.validate_video(row, evidence)

    def test_unexpected_hosts_and_non_exercise_destinations_fail(self):
        source = next(iter(self.data[4].values()))
        for url in ['https://staging.musclewiki.com/exercise/example', 'https://musclewiki.com/api/exercises', 'https://other.example/exercise/example']:
            row = dict(source, url=url)
            with self.assertRaises(ValueError):
                media.validate_video(row, self.data[6][row['id']])


if __name__ == '__main__':
    unittest.main()
