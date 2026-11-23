"""Export reviewed authoring briefs, not images or runtime media approvals.

--write creates the original-38 inventory, current-gap specs, prompt JSONL and
an explicitly ungenerated manifest. --check validates these deterministic files
without network access. No workout data, catalog or runtime registry is written.
"""
import argparse
import csv
import hashlib
import io
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATE = '2026-11-02'
STYLE = (
    'Create an original, unbranded instructional fitness illustration sequence. '
    'Use a consistent adult anatomical mannequin, matte light-gray body, athletic shorts, '
    'charcoal background, clear soft lighting and restrained coral highlights only on the '
    'specified primary muscles. Keep equipment and hands readable. No labels, logos, '
    'watermarks, copied characters, imitation of a named artist or photographic textures. '
    'Keep the same athlete, camera, proportions and equipment in every phase. '
    'Show the entire body, required machine structure and all load/contact points. '
    'Use separate equally sized panels in the specified phase order with ample margins. '
    'Do not sacrifice correct mechanics to achieve a dramatic pose. '
    'This is a draft requiring human anatomical, equipment and movement review.'
)


def read(path):
    return json.loads((ROOT / path).read_text(encoding='utf-8-sig'))


def digest(value):
    return hashlib.sha256(value).hexdigest()


def json_text(value):
    return json.dumps(value, ensure_ascii=False, indent=2) + '\n'


def artifacts():
    with (ROOT / 'docs/exercise-media-coverage.csv').open(encoding='utf-8-sig', newline='') as f:
        coverage = list(csv.DictReader(f))
    catalog = read('lib/assets/data/exercises_catalog.json')['exercises']
    by_id = {r['exercise_id']: r for r in coverage}
    assert len(by_id) == len(coverage) == len(catalog) == 180
    assert by_id.keys() == {r['id'] for r in catalog}
    for row in catalog:
        assert all(row[field] == by_id[row['id']][field]
                   for field in ('name_en', 'name_ar', 'muscle_group', 'equipment'))
    batch = read('docs/exercise-media-batch-review.json')
    original = {r['exerciseId']: r for r in batch['reviews']}
    assert len(original) == 38
    missing = [r for r in coverage if r['image_status'] != 'verified']
    briefs = read('tool/original_exercise_illustration_briefs.json')
    assert {r['exercise_id'] for r in missing} <= briefs.keys()
    assert {r['exercise_id'] for r in missing} <= original.keys()
    approved = read('lib/assets/exercise_illustrations/manifest.json')
    required = ('startingPosition', 'endingPosition', 'jointMovement', 'equipmentDetails',
                'gripAndStance', 'cameraAngle', 'primaryMuscles', 'accuracyRequirements')
    specs = []
    inventory = []
    for row in coverage:
        id = row['exercise_id']
        if id not in original:
            continue
        status = 'already approved in batch continuation' if row['image_status'] == 'verified' else 'requires original generation and review'
        brief = briefs.get(id)
        reference = (
            'Original staged diagram or rights-cleared coach demonstration: ' + brief['cameraAngle'] + ' Equipment: ' + brief['equipmentDetails']
            if brief else 'Existing visually approved illustration: ' + row['image_source']
        )
        inventory.append({
            'exercise_id': id, 'name_en': row['name_en'], 'name_ar': row['name_ar'],
            'primary_muscle_group': row['muscle_group'], 'equipment': row['equipment'],
            'exercise_variation': row['variation_requirements'], 'movement_pattern': row['movement_pattern'],
            'current_status': status, 'reason_image_search_failed_or_resolution': original[id]['review'],
            'recommended_visual_reference': reference,
            'verified_movement_page_reference_only': row['musclewiki_page'],
            'reference_reuse_permission': 'Observation reference only; no image/video reuse grant is asserted.',
        })
        if row['image_status'] == 'verified':
            continue
        assert brief and all(brief.get(k) for k in required), id
        phases = brief.get('phases', [brief['startingPosition'], brief['endingPosition']])
        refs = [{'url': row['musclewiki_page'], 'purpose': 'Existing verified public movement page; external observation only, no media copying.'}] if row['musclewiki_page'] else []
        if id == 'ex_bayesian_cable_curl':
            refs.append({'url': 'https://doi.org/10.3389/fphys.2026.1750722',
                         'purpose': 'Shoulder-extension/elbow-flexion position reference; do not copy the experimental figure.'})
        if id in ('ex_power_clean', 'ex_hang_clean'):
            refs.append({'url': 'https://www.nsca.com/education/articles/kinetic-select/power-clean-from-hang/',
                         'purpose': 'Hang-start and turnover mechanics reference only. Power clean must instead start on floor; catalog catch requirements take precedence.'})
        if id == 'ex_kettlebell_turkish_get_up':
            refs.append({'url': 'https://www.catalystathletics.com/exercise/481/Turkish-Get-up/',
                         'purpose': 'Staged support transitions as a movement reference only; copyrighted media must not be copied.'})
        spec = {'exerciseId': id, 'nameEn': row['name_en'], 'nameAr': row['name_ar'],
                'catalogMuscleGroup': row['muscle_group'], 'catalogEquipment': row['equipment'],
                'catalogVariationRequirements': row['variation_requirements'],
                'specificationStatus': 'prepared; image not generated or approved',
                **brief, 'phases': phases, 'recommendedVisualReference': reference,
                'movementReferences': refs}
        prompt = STYLE + '\n\nExercise: ' + row['name_en'] + '\n'
        prompt += '\n'.join(key + ': ' + (json.dumps(spec[key], ensure_ascii=False) if isinstance(spec[key], list) else spec[key]) for key in required)
        prompt += '\nOrdered phases: ' + json.dumps(phases, ensure_ascii=False)
        spec['generationPrompt'] = prompt
        spec['promptSha256'] = digest(prompt.encode('utf-8'))
        specs.append(spec)
    catalog_sha = digest((ROOT / 'lib/assets/data/exercises_catalog.json').read_bytes())
    totals = {'catalogAudited': 180, 'originalGapInventory': 38,
              'originalGapsNowApproved': 38-len(missing), 'approvedIllustrations': len(approved),
              'requiresGeneration': len(missing), 'generatedInThisPreparation': 0}
    manifest = {'schemaVersion': 1, 'preparedOn': DATE, 'catalogSha256': catalog_sha,
                'status': 'specifications only; no generation performed', 'totals': totals,
                'generationCapability': 'Image generation is available in this environment; intentionally deferred until after this inventory/specification deliverable.',
                'preservation': {'approvedImages': [{k: r[k] for k in ('exerciseId', 'assetPath', 'assetSha256', 'sourceUrl')} for r in approved],
                                 'videoReviewsSha256': digest((ROOT / 'tool/exercise_media_video_reviews.tsv').read_bytes())},
                'outputRequirements': {'masterFormat': 'PNG', 'masterMinimumLongestEdge': 1536,
                                       'layout': 'Two panels for start/end; three to six ordered panels where sequence defines the variation.',
                                       'runtimeFormatAfterApproval': 'WebP, maximum 512 pixels per axis, bounded decode; no runtime network requests.',
                                       'runtimeApproval': 'Manual equipment, grip, stance, body position, movement, anatomy and rights/provenance review; never autoapprove generation output.'},
                'jobs': []}
    for spec in specs:
        id = spec['exerciseId']
        manifest['jobs'].append({'exerciseId': id, 'nameEn': spec['nameEn'], 'promptSha256': spec['promptSha256'],
                                 'generationStatus': 'not_started', 'reviewStatus': 'pending', 'approved': False,
                                 'proposedDraftPath': f'build/exercise-illustration-drafts/{id}--sequence.png',
                                 'proposedRuntimePathAfterApproval': f'lib/assets/exercise_illustrations/{id}.webp',
                                 'actualOutputPath': None, 'outputSha256': None, 'generatedOn': None,
                                 'provider': None, 'modelVersion': None, 'generationTermsOrRightsGrant': None,
                                 'referenceImageRights': [], 'reviewer': None, 'reviewNotes': None,
                                 'phaseCount': len(spec['phases'])})
    stream = io.StringIO(newline='')
    writer = csv.DictWriter(stream, fieldnames=inventory[0].keys(), lineterminator='\n')
    writer.writeheader()
    writer.writerows(inventory)
    md = ['# Original exercise illustration specifications', '',
          f'Prepared {DATE}. **{len(specs)} images require generation and visual review. No images were generated by this export.**', '',
          'The original 38-gap inventory now contains two approved additions (underhand barbell row and chest-supported machine row). All 144 approved mappings remain preserved. Original catalog names, equipment and muscle categories are unchanged.', '',
          'The CSV covers all original 38 entries, including Arabic names, search failures, variations and recommended references. The JSON/JSONL below cover only the 36 still missing. Public demonstration links are observation references, not licenses to copy images or videos.', '',
          '## Final bounded licensed search', '',
          'One focused query per current gap (36 total) was completed, reusing the existing source audit. No additional asset was approved; search snippets alone were not treated as a rights grant. This records the search outcome, not proof that no free asset exists. Search evidence and inspected-result decisions are in exercise-illustration-final-search.json. No repeat search loop or speculative import was performed.', '',
          'The Commons “Power Clean Ico” result is an Android cleaner app icon, not weightlifting art. The Bayesian-curl research figure is useful for movement reference but is not a clean isolated thumbnail. NSCA/Human Kinetics and Catalyst Athletics pages are movement references only; their media were not copied.', '',
          '## Generation and review workflow', '',
          'Use the JSONL prompts and manifest to generate original drafts. Keep draft files outside runtime asset directories. Record actual provider, model/version, time, prompt hash, output hash, generation terms/rights and any rights-cleared reference inputs. Do not claim a Creative Commons license for generated art automatically.', '',
          'Review labeled contact sheets of 20–30 candidates, then inspect individual frames where movement, equipment or anatomy is ambiguous. Verify every phase and reject extra limbs, changing equipment, wrong cable origins, wrong load contact, wrong grip and substituted variations. Only after approval optimize locally, retain provenance, add explicit ID mapping and regenerate the 180-row coverage report. Never alter user workout/storage data.', '',
          'Illustration setup choices such as a particular leg-press sled angle, double-dumbbell clean-and-press, calf block or hang-clean receiving depth are explicit authoring choices, not changes to catalog semantics. The hang-clean catch-depth choice requires reviewer confirmation before approval.', '',
          '## Shared visual direction', '', STYLE, '']
    md += ['## Assets still requiring generation', '',
           '| Exercise ID | English | Arabic | Equipment |',
           '| --- | --- | --- | --- |']
    md += [f'| {r["exerciseId"]} | {r["nameEn"]} | {r["nameAr"]} | {r["catalogEquipment"]} |' for r in specs]
    md += ['', 'Every item below is a specification only, with no generated or approved image.', '']
    for spec in specs:
        md += [f'## {spec["nameEn"]} — {spec["nameAr"]}', '',
               f'ID: `{spec["exerciseId"]}`. Catalog: {spec["catalogMuscleGroup"]}; {spec["catalogEquipment"]}.', '',
               'Required variation: ' + spec['catalogVariationRequirements'], '']
        for key in required:
            value = spec[key]
            label = {'startingPosition': 'Starting position', 'endingPosition': 'Ending position',
                     'jointMovement': 'Joint movement', 'equipmentDetails': 'Equipment',
                     'gripAndStance': 'Grip and stance', 'cameraAngle': 'Camera angle',
                     'primaryMuscles': 'Primary muscles to highlight', 'accuracyRequirements': 'Visual acceptance requirements'}[key]
            md += ['**' + label + ':** ' + ('; '.join(value) if isinstance(value, list) else value), '']
        md += ['**Ordered phases:** ' + ' → '.join(spec['phases']), '']
        if spec['movementReferences']:
            md += ['**Observation references:** ' + '; '.join('[' + ref['purpose'] + '](' + ref['url'] + ')' for ref in spec['movementReferences']), '']
    return {
        'docs/exercise-illustration-completion-inventory.csv': '\ufeff' + stream.getvalue(),
        'docs/exercise-illustration-specifications.json': json_text({'preparedOn': DATE, 'totals': totals, 'style': STYLE, 'exercises': specs}),
        'docs/exercise-illustration-generation-manifest.json': json_text(manifest),
        'docs/exercise-illustration-prompts.jsonl': ''.join(json.dumps({'custom_id': r['exerciseId'], 'prompt': r['generationPrompt'], 'promptSha256': r['promptSha256']}, ensure_ascii=False) + '\n' for r in specs),
        'docs/exercise-illustration-specifications.md': '\n'.join(md) + '\n',
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    assert args.write != args.check, 'Choose exactly one of --write / --check'
    for name, content in artifacts().items():
        path = ROOT / name
        if args.write:
            path.write_text(content, encoding='utf-8', newline='')
        else:
            assert path.read_bytes() == content.encode('utf-8'), 'Export drift: ' + name
    print('Validated original 38-gap inventory; 36 complete specifications/prompts; 0 generated images. Approved media preserved.')


if __name__ == '__main__':
    main()
