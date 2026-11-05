"""Build the explicit, conservative application compatibility table.

No name similarity is used to approve a mapping. Unreviewed variations remain
legacy references, even when a fuzzy candidate exists in the larger catalog.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMMIT = '66c4298af8d99b9dc397dad6699e508fb871d249'
# Equipment, movement, position and grip reviewed against the pinned English
# descriptions/instructions and the original exercise-media variation inventory.
EXACT = {
    'ex_barbell_bench_press': 'bench-press',
    'ex_incline_barbell_bench_press': 'incline-bench-press',
    'ex_dumbbell_bench_press': 'db-bench-press',
    'ex_incline_dumbbell_press': 'incline-db-press',
    'ex_dumbbell_fly': 'db-fly',
    'ex_machine_chest_press': 'chest-press-machine',
    'ex_pec_deck_fly': 'pec-deck',
    'ex_cable_chest_fly': 'cable-fly',
    'ex_lat_pulldown': 'lat-pulldown',
    'ex_seated_cable_row': 'seated-cable-row',
    'ex_chest_supported_dumbbell_row': 'chest-supported-db-row',
    'ex_straight_arm_cable_pulldown': 'straight-arm-pulldown',
    'ex_dumbbell_shoulder_press': 'dumbbell-shoulder-press',
    'ex_machine_shoulder_press': 'machine-shoulder-press',
    'ex_dumbbell_lateral_raise': 'lateral-raise',
    'ex_cable_lateral_raise': 'cable-lateral-raise',
    'ex_reverse_pec_deck': 'machine-reverse-fly',
    'ex_cable_rear_delt_fly': 'cable-reverse-fly',
    'ex_ez_bar_curl': 'ez-bar-curl',
    'ex_hammer_curl': 'hammer-curl',
    'ex_incline_dumbbell_curl': 'incline-db-curl',
    'ex_overhead_cable_triceps_extension': 'cable-overhead-tricep-extension',
    'ex_close_grip_bench_press': 'close-grip-bench-press',
    'ex_barbell_back_squat': 'squat',
    'ex_leg_extension': 'leg-extension',
    'ex_bulgarian_split_squat': 'bulgarian-split-squat',
    'ex_romanian_deadlift': 'romanian-deadlift',
    'ex_seated_leg_curl': 'seated-leg-curl',
    'ex_lying_leg_curl': 'leg-curl',
    'ex_barbell_hip_thrust': 'hip-thrust',
    'ex_standing_calf_raise_machine': 'standing-calf-raise',
    'ex_seated_calf_raise_machine': 'seated-calf-raise',
    'ex_cable_crunch': 'cable-crunch',
    'ex_reverse_crunch': 'reverse-crunches',
    'ex_hanging_knee_raise': 'hanging-knee-raise',
}
REASONS = {
    'ex_rope_triceps_pushdown': 'The official tricep-pushdown explicitly uses a straight bar, not a rope. V-bar and single-arm entries are different variations.',
    'ex_neutral_grip_lat_pulldown': 'Official neutral-handle candidates specify a narrow/close grip. The legacy reference does not establish that width; no silent substitution.',
    'ex_leg_press_45': 'The official generic leg-press instructions do not establish a 45-degree sled angle. Preserve the specific legacy angle.',
}


def main():
    load = lambda p: json.loads((ROOT / p).read_text(encoding='utf-8'))
    old = load('lib/assets/data/exercises_catalog.json')['exercises']
    new = {e['id']: e for e in load('lib/assets/repdb/exercises.json')['exercises']}
    rows = []
    for exercise in old:
        target = EXACT.get(exercise['id'])
        if target:
            assert target in new
        rows.append({
            'legacy_id': exercise['id'],
            'canonical_id': f'repdb:{target}' if target else None,
            'status': 'exact' if target else 'unmatched',
            'evidence': (
                f"Legacy {exercise['name_en']} ({exercise['equipment']}); "
                f"official {new[target]['name_en']} ({new[target].get('equipment', 'not supplied')}). "
                + new[target]['description_en']
            ) if target else REASONS.get(exercise['id'],
                'No individually reviewed exact equipment/grip/position/movement equivalence. Retain the legacy ID and snapshot; replacement requires an explicit user selection.'),
        })
    data = {'version': 1, 'dataset_commit': COMMIT, 'mappings': rows}
    (ROOT / 'lib/assets/repdb/legacy-mapping.json').write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'{len(EXACT)} exact mappings; {len(rows) - len(EXACT)} legacy references retained.')


if __name__ == '__main__':
    main()
