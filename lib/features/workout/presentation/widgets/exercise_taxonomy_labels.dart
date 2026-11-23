/// Labels translate recorded taxonomy values, never infer muscle assignments.
abstract final class ExerciseTaxonomyLabels {
  static String _label(
    Map<String, (String, String)> values,
    String id,
    String language,
    String Function(String)? fallback,
  ) {
    final pair = values[id];
    return pair == null
        ? fallback?.call(id) ?? id.replaceAll('_', ' ')
        : language.startsWith('ar')
        ? pair.$2
        : pair.$1;
  }

  static String muscle(
    String id,
    String language, {
    String Function(String)? fallback,
  }) => _label(_muscles, id, language, fallback);
  static String equipment(
    String id,
    String language, {
    String Function(String)? fallback,
  }) => _label(_equipment, id, language, fallback);
  static String category(String id, String language) =>
      _label(_categories, id, language, null);
  static const _categories = {
    'strength': ('Strength', 'قوة'),
    'stretching': ('Stretching', 'إطالات'),
    'cardio': ('Cardio', 'كارديو'),
    'plyometrics': ('Plyometrics', 'تمارين انفجارية'),
    'olympic': ('Olympic lifting', 'رفع أثقال أوليمبي'),
  };
  static const _muscles = {
    'back': ('Back', 'الظهر'),
    'chest': ('Chest', 'الصدر'),
    'core': ('Core', 'الجذع'),
    'full_body': ('Full body', 'الجسم كاملًا'),
    'lower_arms': ('Forearms', 'الساعدان'),
    'lower_legs': ('Lower legs', 'أسفل الرجلين'),
    'shoulders': ('Shoulders', 'الكتف'),
    'upper_arms': ('Upper arms', 'أعلى الذراعين'),
    'upper_legs': ('Upper legs', 'الفخذان'),
    'abductors': ('Hip abductors', 'عضلات فتح الفخذ'),
    'adductors': ('Hip adductors', 'عضلات ضم الفخذ'),
    'anterior_deltoid': ('Front deltoids', 'الكتف الأمامي'),
    'biceps_brachii': ('Biceps', 'البايسبس'),
    'brachialis': ('Brachialis', 'العضدية'),
    'brachioradialis': ('Brachioradialis', 'العضدية الكعبرية'),
    'erector_spinae': ('Spinal erectors', 'ناصبات العمود الفقري'),
    'forearm_extensors': ('Forearm extensors', 'باسطات الساعد'),
    'forearm_flexors': ('Forearm flexors', 'مثنيات الساعد'),
    'forearms': ('Forearms', 'الساعدان'),
    'gastrocnemius': ('Gastrocnemius', 'السمانة التوأمية'),
    'gluteus_maximus': ('Gluteus maximus', 'الأرداف الكبرى'),
    'gluteus_medius': ('Gluteus medius', 'الأرداف الوسطى'),
    'hamstrings': ('Hamstrings', 'خلفية الفخذ'),
    'hip_flexors': ('Hip flexors', 'مثنيات الورك'),
    'infraspinatus_teres_minor': (
      'Infraspinatus / teres minor',
      'تحت الشوكة والمدورة الصغرى',
    ),
    'lateral_deltoid': ('Side deltoids', 'الكتف الجانبي'),
    'latissimus_dorsi': ('Lats', 'عضلات الظهر العريضة'),
    'obliques': ('Obliques', 'عضلات البطن المائلة'),
    'pectoralis_major': ('Pectoralis major', 'عضلة الصدر الكبرى'),
    'posterior_deltoid': ('Rear deltoids', 'الكتف الخلفي'),
    'quadratus_lumborum': ('Quadratus lumborum', 'العضلة المربعة القطنية'),
    'quadriceps': ('Quadriceps', 'أمامية الفخذ'),
    'rectus_abdominis': ('Rectus abdominis', 'عضلة البطن المستقيمة'),
    'rhomboids': ('Rhomboids', 'العضلات المعينية'),
    'serratus_anterior': ('Serratus anterior', 'العضلة المنشارية الأمامية'),
    'soleus': ('Soleus', 'العضلة النعلية'),
    'supraspinatus': ('Supraspinatus', 'العضلة فوق الشوكة'),
    'tibialis_anterior': ('Tibialis anterior', 'الظنبوبية الأمامية'),
    'transverse_abdominis': ('Transverse abdominis', 'عضلة البطن المستعرضة'),
    'trapezius': ('Traps', 'الترابيس'),
    'triceps_brachii': ('Triceps', 'الترايسبس'),
  };
  static const _equipment = {
    'ab_wheel': ('Ab wheel', 'عجلة البطن'),
    'air_bike': ('Air bike', 'عجلة هوائية بالمقاومة'),
    'pull_up_bar': ('Pull-up bar', 'بار العقلة'),
    'dumbbell': ('Dumbbell', 'دمبل'),
    'dip_machine': ('Dip machine', 'جهاز المتوازي'),
    'assisted_pullup_machine': (
      'Assisted pull-up machine',
      'جهاز العقلة المساعد',
    ),
    'bosu_ball': ('Balance dome', 'كرة توازن نصفية'),
    'stability_ball': ('Stability ball', 'كرة التوازن'),
    'resistance_band': ('Resistance band', 'حبل مقاومة'),
    'loop_band': ('Loop band', 'رباط مقاومة دائري'),
    'barbell': ('Barbell', 'بار'),
    'battle_rope': ('Battle rope', 'حبل قتالي'),
    'lat_pulldown_machine': ('Lat pulldown machine', 'جهاز السحب العلوي'),
    'flat_bench': ('Flat bench', 'مقعد مستوٍ'),
    'ez_bar': ('EZ bar', 'بار EZ'),
    'plyo_box': ('Plyometric box', 'صندوق قفز'),
    'cable': ('Cable', 'كابل'),
    'chest_press_machine': ('Chest press machine', 'جهاز ضغط الصدر'),
    'kettlebell': ('Kettlebell', 'كيتل بيل'),
    'seated_row_machine': ('Seated row machine', 'جهاز التجديف الجالس'),
    'smith_machine': ('Smith machine', 'جهاز سميث'),
    'leg_press': ('Leg press', 'جهاز ضغط الرجلين'),
    'bicycle': ('Bicycle', 'دراجة'),
    'dip_station': ('Dip bars', 'متوازي'),
    'elliptical': ('Elliptical', 'إليبتيكال'),
    'hack_squat': ('Hack squat machine', 'جهاز الهاك سكوات'),
    'trap_bar': ('Trap bar', 'بار سداسي'),
    'hip_abduction_machine': ('Hip abduction machine', 'جهاز فتح الفخذين'),
    'hip_adduction_machine': ('Hip adduction machine', 'جهاز ضم الفخذين'),
    'treadmill': ('Treadmill', 'سير جري'),
    'jump_rope': ('Jump rope', 'حبل نط'),
    'leg_curl': ('Leg curl machine', 'جهاز الرجل الخلفي'),
    'leg_extension': ('Leg extension machine', 'جهاز فرد الرجلين'),
    'back_extension_machine': ('Back extension machine', 'جهاز فرد الظهر'),
    'bicep_curl_machine': ('Biceps curl machine', 'جهاز البايسبس'),
    'standing_calf_raise_machine': (
      'Standing calf raise machine',
      'جهاز السمانة الواقف',
    ),
    'chest_fly_machine': ('Chest fly machine', 'جهاز تفتيح الصدر'),
    'preacher_curl_machine': ('Preacher curl machine', 'جهاز بايسبس الارتكاز'),
    'reverse_fly_machine': ('Reverse fly machine', 'جهاز الفراشة العكسية'),
    'ab_crunch_machine': ('Ab crunch machine', 'جهاز كرنش البطن'),
    'shoulder_press_machine': ('Shoulder press machine', 'جهاز ضغط الكتف'),
    'tricep_extension_machine': (
      'Triceps extension machine',
      'جهاز فرد الترايسبس',
    ),
    'medicine_ball': ('Medicine ball', 'كرة طبية'),
    'slam_ball': ('Slam ball', 'كرة ضرب'),
    'glute_ham_developer': ('Glute-ham developer', 'جهاز خلفية الفخذ والأرداف'),
    'pec_deck': ('Pec deck', 'جهاز البيك ديك'),
    'donkey_calf_raise_machine': (
      'Donkey calf raise machine',
      'جهاز سمانة دونكي',
    ),
    'hip_thrust_machine': ('Hip thrust machine', 'جهاز دفع الحوض'),
    'plate_loaded_lateral_raise_machine': (
      'Plate-loaded lateral raise',
      'جهاز رفرفة جانبي بالأقراص',
    ),
    'plate_loaded_dip_machine': (
      'Plate-loaded dip machine',
      'جهاز متوازي بالأقراص',
    ),
    'shrug_machine': ('Shrug machine', 'جهاز الترابيس'),
    'plates': ('Weight plates', 'أقراص أوزان'),
    'rings': ('Rings', 'حلقات'),
    'climbing_rope': ('Climbing rope', 'حبل تسلق'),
    'rower': ('Rowing machine', 'جهاز تجديف'),
    'sandbag': ('Sandbag', 'كيس رمل'),
    'seated_calf_raise_machine': (
      'Seated calf raise machine',
      'جهاز السمانة الجالس',
    ),
    'ski_erg': ('SkiErg', 'جهاز سكي إرغ'),
    'sled': ('Sled', 'زلاجة تدريب'),
    'stair_climber': ('Stair climber', 'جهاز صعود السلم'),
    'stationary_bike': ('Stationary bike', 'عجلة ثابتة'),
    'suspension_trainer': ('Suspension trainer', 'أحزمة تعليق'),
    'wall_ball': ('Wall ball', 'كرة حائط'),
    'wrist_roller': ('Wrist roller', 'بكرة رسغ'),
  };
}
