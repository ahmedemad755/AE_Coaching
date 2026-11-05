"""Validate handover completeness and the boundary between prompts and approvals."""
import csv
import hashlib
import json
import unittest

from prepare_original_exercise_specs import ROOT, artifacts


class OriginalIllustrationSpecificationTests(unittest.TestCase):
    def test_every_remaining_exercise_has_exact_metadata_and_complete_brief(self):
        exports = artifacts()
        specs = json.loads(exports['docs/exercise-illustration-specifications.json'])['exercises']
        with (ROOT / 'docs/exercise-media-coverage.csv').open(encoding='utf-8-sig', newline='') as f:
            missing = {r['exercise_id']: r for r in csv.DictReader(f) if r['image_status'] != 'verified'}
        self.assertEqual(len(specs), 36)
        self.assertEqual({r['exerciseId'] for r in specs}, missing.keys())
        for spec in specs:
            row = missing[spec['exerciseId']]
            self.assertEqual((spec['nameEn'], spec['nameAr'], spec['catalogEquipment'], spec['catalogMuscleGroup']),
                             (row['name_en'], row['name_ar'], row['equipment'], row['muscle_group']))
            for field in ('startingPosition', 'endingPosition', 'jointMovement', 'equipmentDetails',
                          'gripAndStance', 'cameraAngle', 'primaryMuscles', 'accuracyRequirements'):
                self.assertTrue(spec[field], (spec['exerciseId'], field))
            self.assertGreaterEqual(len(spec['phases']), 2)
            self.assertEqual(hashlib.sha256(spec['generationPrompt'].encode('utf-8')).hexdigest(), spec['promptSha256'])

    def test_generation_manifest_cannot_claim_created_or_approved_assets(self):
        exports = artifacts()
        manifest = json.loads(exports['docs/exercise-illustration-generation-manifest.json'])
        self.assertEqual(manifest['totals']['generatedInThisPreparation'], 0)
        self.assertEqual(len(manifest['jobs']), 36)
        self.assertEqual(len(manifest['preservation']['approvedImages']), 144)
        for job in manifest['jobs']:
            self.assertIs(job['approved'], False)
            self.assertEqual(job['generationStatus'], 'not_started')
            self.assertEqual(job['reviewStatus'], 'pending')
            for field in ('actualOutputPath', 'outputSha256', 'provider', 'modelVersion', 'generatedOn',
                          'generationTermsOrRightsGrant', 'reviewer'):
                self.assertIsNone(job[field])
        for art in manifest['preservation']['approvedImages']:
            self.assertEqual(hashlib.sha256((ROOT / art['assetPath']).read_bytes()).hexdigest(), art['assetSha256'])
        self.assertEqual(hashlib.sha256((ROOT / 'tool/exercise_media_video_reviews.tsv').read_bytes()).hexdigest(),
                         manifest['preservation']['videoReviewsSha256'])

    def test_exported_handover_files_are_current_and_original_gap_ids_are_unique(self):
        exports = artifacts()
        for name, content in exports.items():
            self.assertEqual((ROOT / name).read_bytes(), content.encode('utf-8'), name)
        inventory = list(csv.DictReader(exports['docs/exercise-illustration-completion-inventory.csv'].lstrip('\ufeff').splitlines()))
        self.assertEqual(len(inventory), 38)
        self.assertEqual(len({r['exercise_id'] for r in inventory}), 38)
        completed = {r['exercise_id'] for r in inventory if r['current_status'].startswith('already approved')}
        self.assertEqual(completed, {'ex_underhand_barbell_row', 'ex_chest_supported_machine_row'})


if __name__ == '__main__':
    unittest.main()
