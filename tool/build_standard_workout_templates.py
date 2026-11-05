"""Author deterministic application data using only existing exercise IDs."""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
catalog = {'repdb:' + e['id']: e for e in json.loads((ROOT / 'lib/assets/repdb/exercises.json').read_text(encoding='utf-8'))['exercises']}


def e(name, sets=3, low=8, high=12, rest=150):
    id = 'repdb:' + name
    assert id in catalog, id
    return dict(exercise_id=id, working_sets=sets, reps_min=low, reps_max=high, rest_seconds=rest)


def iso(name, sets=2, low=12, high=15, rest=90):
    return e(name, sets, low, high, rest)


def day(id, en, ar, *exercises):
    assert len({e['exercise_id'] for e in exercises}) == len(exercises)
    return dict(id=id, name_en=en, name_ar=ar, exercises=list(exercises))


push_a = day('push_a', 'Push A', 'دفع أ', e('bench-press',3,6,10,180), e('incline-db-press',2),
             e('dumbbell-shoulder-press',2), iso('lateral-raise',3,12,20), iso('tricep-pushdown'))
push_b = day('push_b', 'Push B', 'دفع ب', e('incline-bench-press',3,6,10,180), e('chest-press-machine',2),
             e('machine-shoulder-press',2), iso('cable-lateral-raise',3,12,20), iso('cable-overhead-tricep-extension'))
pull_a = day('pull_a', 'Pull A', 'سحب أ', e('lat-pulldown'), e('seated-cable-row'), iso('machine-reverse-fly'),
             iso('ez-bar-curl',2,10,15), iso('hammer-curl',2,10,15))
pull_b = day('pull_b', 'Pull B', 'سحب ب', e('close-grip-lat-pulldown'), e('chest-supported-db-row'),
             iso('cable-reverse-fly'), iso('incline-db-curl',2,10,15))
legs_a = day('legs_a', 'Legs A', 'أرجل أ', e('squat',3,6,10,180), e('romanian-deadlift',3,8,10,180),
             iso('leg-extension'), iso('leg-curl'), iso('standing-calf-raise',3,10,20))
legs_b = day('legs_b', 'Legs B', 'أرجل ب', e('leg-press',3,10,15,180), e('hip-thrust',2),
             e('bulgarian-split-squat',2,8,12,150), iso('seated-leg-curl',3), iso('seated-calf-raise',3,12,20))
upper_a = day('upper_a', 'Upper A', 'علوي أ', e('bench-press',3,6,10,180), e('seated-cable-row'),
              e('incline-db-press',2), e('lat-pulldown',2), iso('lateral-raise',2,12,20),
              iso('ez-bar-curl',2,10,15), iso('tricep-pushdown'))
upper_b = day('upper_b', 'Upper B', 'علوي ب', e('incline-bench-press',3,6,10,180), e('chest-supported-db-row'),
              e('dumbbell-shoulder-press',2), e('close-grip-lat-pulldown',2), iso('machine-reverse-fly'),
              iso('hammer-curl',2,10,15), iso('cable-overhead-tricep-extension'))
lower_a = day('lower_a', 'Lower A', 'سفلي أ', *legs_a['exercises'], iso('cable-crunch',2,10,20,60))
lower_b = day('lower_b', 'Lower B', 'سفلي ب', *legs_b['exercises'], iso('hanging-knee-raise',2,10,20,60))

full_a = day('full_a','Full Body A','الجسم كامل أ',e('squat',3,6,10,180),e('bench-press',3,6,10,180),
             e('seated-cable-row'),iso('leg-curl'),iso('lateral-raise',2,12,20),
             iso('standing-calf-raise',2,10,20),iso('cable-crunch',2,10,20,60))
full_b = day('full_b','Full Body B','الجسم كامل ب',e('romanian-deadlift',3,8,10,180),e('incline-db-press'),
             e('lat-pulldown'),iso('leg-extension'),iso('ez-bar-curl',2,10,15),iso('tricep-pushdown'))
full_c = day('full_c','Full Body C','الجسم كامل ج',e('leg-press',3,10,15,180),e('db-bench-press'),
             e('chest-supported-db-row'),iso('seated-leg-curl',3),e('dumbbell-shoulder-press',2),
             iso('seated-calf-raise',2,12,20),iso('reverse-crunches',2,10,20,60))

ppl3_push = day('push','Push','دفع', e('bench-press',3,6,10,180),e('incline-db-press'),
                 e('dumbbell-shoulder-press',2),iso('lateral-raise',3,12,20),iso('tricep-pushdown',3))
ppl3_pull = day('pull','Pull','سحب',e('lat-pulldown'),e('seated-cable-row'),iso('machine-reverse-fly',3),
                 iso('ez-bar-curl',3,10,15),iso('hammer-curl',2,10,15))
ppl3_legs = day('legs','Legs','أرجل',e('squat',3,6,10,180),e('romanian-deadlift',3,8,10,180),
                 e('leg-press',2,10,15,180),iso('leg-curl',3),iso('standing-calf-raise',3,10,20),iso('cable-crunch',2,10,20,60))
bro_chest = day('chest','Chest','صدر',e('bench-press',3,6,10,180),e('incline-db-press'),iso('db-fly'),iso('pec-deck'))
bro_back = day('back','Back','ظهر',e('lat-pulldown'),e('seated-cable-row'),e('chest-supported-db-row',2),iso('straight-arm-pulldown'),iso('machine-reverse-fly'))
bro_shoulders = day('shoulders','Shoulders','أكتاف',e('dumbbell-shoulder-press'),iso('lateral-raise',3,12,20),iso('cable-reverse-fly',3),iso('cable-crunch',2,10,20,60))
bro_arms = day('arms','Arms','ذراعان',iso('ez-bar-curl',3,10,15),iso('incline-db-curl',2,10,15),iso('hammer-curl',2,10,15),
               e('close-grip-bench-press',3,8,12,150),iso('tricep-pushdown'),iso('cable-overhead-tricep-extension'))
arnold_chest = day('chest_back','Chest & Back','صدر وظهر',e('bench-press',3,6,10,180),e('lat-pulldown'),e('incline-db-press'),e('seated-cable-row'),iso('straight-arm-pulldown'))
arnold_arms = day('shoulders_arms','Shoulders & Arms','أكتاف وذراعان',e('dumbbell-shoulder-press'),iso('lateral-raise',3,12,20),iso('machine-reverse-fly'),
                  iso('ez-bar-curl',3,10,15),iso('incline-db-curl',2,10,15),iso('tricep-pushdown',3),iso('cable-overhead-tricep-extension'))
arnold_a = day('chest_back_a','Chest & Back A','صدر وظهر أ',e('bench-press',3,6,10,180),e('lat-pulldown'),e('incline-db-press',2),e('seated-cable-row',2))
arnold_b = day('chest_back_b','Chest & Back B','صدر وظهر ب',e('db-bench-press'),e('chest-supported-db-row'),iso('cable-fly'),e('close-grip-lat-pulldown',2))
arnold_sa = day('shoulders_arms_a','Shoulders & Arms A','أكتاف وذراعان أ',e('dumbbell-shoulder-press',2),iso('lateral-raise',3,12,20),iso('ez-bar-curl',2,10,15),iso('tricep-pushdown'),iso('machine-reverse-fly'))
arnold_sb = day('shoulders_arms_b','Shoulders & Arms B','أكتاف وذراعان ب',e('machine-shoulder-press',2),iso('cable-lateral-raise',3,12,20),iso('incline-db-curl',2,10,15),iso('cable-overhead-tricep-extension'),iso('cable-reverse-fly'))

ant_a = day('anterior_a','Anterior A','أمامي أ',e('bench-press',3,6,10,180),e('squat',3,6,10,180),iso('lateral-raise',2,12,20),iso('ez-bar-curl',2,10,15),iso('leg-extension'),iso('cable-crunch',2,10,20,60))
post_a = day('posterior_a','Posterior A','خلفي أ',e('romanian-deadlift',3,8,10,180),e('lat-pulldown'),e('chest-supported-db-row',2),iso('cable-reverse-fly'),iso('tricep-pushdown'),iso('standing-calf-raise',3,10,20))
ant_b = day('anterior_b','Anterior B','أمامي ب',e('incline-db-press'),e('leg-press',3,10,15,180),e('dumbbell-shoulder-press',2),iso('incline-db-curl',2,10,15),iso('cable-fly'),iso('reverse-crunches',2,10,20,60))
post_b = day('posterior_b','Posterior B','خلفي ب',e('hip-thrust'),iso('seated-leg-curl',3),e('close-grip-lat-pulldown'),e('seated-cable-row',2),iso('machine-reverse-fly'),iso('cable-overhead-tricep-extension'),iso('seated-calf-raise',3,12,20))


def variant(id, days, schedule):
    assert len(schedule)==7 and sorted(i for i in schedule if i is not None)==list(range(len(days)))
    return dict(id=id, days=days, suggested_week=schedule)


three=[0,None,1,None,2,None,None]
six=[0,1,2,3,4,5,None]
four=[0,1,None,2,3,None,None]
five=[0,1,2,None,3,4,None]
splits = [
 dict(id='push_pull_legs',name_en='Push Pull Legs',name_ar='دفع / سحب / أرجل',variants=[variant('ppl_3',[ppl3_push,ppl3_pull,ppl3_legs],three),variant('ppl_6',[push_a,pull_a,legs_a,push_b,pull_b,legs_b],six)]),
 dict(id='upper_lower',name_en='Upper / Lower',name_ar='علوي / سفلي',variants=[variant('upper_lower_4',[upper_a,lower_a,upper_b,lower_b],four)]),
 dict(id='full_body',name_en='Full Body',name_ar='الجسم كامل',variants=[variant('full_body_3',[full_a,full_b,full_c],three)]),
 dict(id='bro_split',name_en='Bro Split',name_ar='تقسيمة عضلة في اليوم',variants=[variant('bro_5',[bro_chest,bro_back,bro_shoulders,ppl3_legs,bro_arms],five)]),
 dict(id='arnold',name_en='Arnold Split',name_ar='تقسيمة أرنولد',variants=[variant('arnold_3',[arnold_chest,arnold_arms,ppl3_legs],three),variant('arnold_6',[arnold_a,arnold_sa,legs_a,arnold_b,arnold_sb,legs_b],six)]),
 dict(id='hybrid',name_en='Hybrid',name_ar='تقسيمة هجينة',variants=[variant('hybrid_5',[
     day('upper','Upper','علوي',*upper_a['exercises']), day('lower','Lower','سفلي',*lower_a['exercises']),
     day('push','Push','دفع',*push_b['exercises']), day('pull','Pull','سحب',*pull_b['exercises']),
     day('legs','Legs','أرجل',*legs_b['exercises'])],[0,1,None,2,3,4,None])]),
 dict(id='anterior_posterior',name_en='Anterior / Posterior',name_ar='أمامي / خلفي',variants=[variant('anterior_posterior_4',[ant_a,post_a,ant_b,post_b],four)]),
]
output=dict(schema_version=1,splits=splits)
# The detailed compatibility audit is maintained in docs; do not overwrite it.
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--check', action='store_true', help='Validate checked-in JSON without writing files.')
args = parser.parse_args()
asset = ROOT / 'lib/assets/data/standard_workout_templates.json'
encoded = json.dumps(output, ensure_ascii=False, indent=2) + '\n'
if args.check:
    assert asset.read_text(encoding='utf-8') == encoded, 'Bundled templates differ from canonical authoring source.'
else:
    asset.write_text(encoded, encoding='utf-8')
print(f"Validated {len(splits)} splits / {sum(len(s['variants']) for s in splits)} variants / 39 days; all IDs canonical RepDB.")
