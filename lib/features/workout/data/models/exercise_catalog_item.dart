class ExerciseCatalogItem {
  final String id;
  final String nameEn;
  final String nameAr;
  final String muscleGroup;
  final String equipment;
  final String? sourceId;
  final String? category;
  final String? forceType;
  final String? movementPattern;
  final String? mechanic;
  final String? difficulty;
  final String? variationGroup;
  final bool isBodyweight;
  final bool isUnilateral;
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final List<String> instructionsEn;
  final List<String> instructionsAr;
  final List<String> tipsEn;
  final List<String> tipsAr;
  final String? startImage;
  final String? peakImage;
  final String? mainImage;
  final String? datasetVersion;
  final String? sourceAttribution;
  final bool arabicNeedsReview;

  const ExerciseCatalogItem({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required this.muscleGroup,
    required this.equipment,
    this.sourceId,
    this.category,
    this.forceType,
    this.movementPattern,
    this.mechanic,
    this.difficulty,
    this.variationGroup,
    this.isBodyweight = false,
    this.isUnilateral = false,
    this.primaryMuscles = const [],
    this.secondaryMuscles = const [],
    this.instructionsEn = const [],
    this.instructionsAr = const [],
    this.tipsEn = const [],
    this.tipsAr = const [],
    this.startImage,
    this.peakImage,
    this.mainImage,
    this.datasetVersion,
    this.sourceAttribution,
    this.arabicNeedsReview = false,
  });

  bool get isRepDb => sourceId != null;

  factory ExerciseCatalogItem.fromRepDb(
    Map<String, dynamic> json, {
    required String datasetVersion,
    Map<String, dynamic>? arabic,
  }) {
    List<String> strings(dynamic value, String field) {
      if (value == null) return const [];
      if (value is! List ||
          value.any((v) => v is! String || v.trim().isEmpty)) {
        throw FormatException('Invalid RepDB $field.');
      }
      return List<String>.unmodifiable(value.cast<String>());
    }

    final sourceId = _requiredString(json, 'id');
    final images = (json['images'] as Map?)?['flat'] as Map? ?? const {};
    String? image(String pose) {
      final value = images[pose];
      if (value == null) return null;
      if (value is! String ||
          !RegExp(r'^images/flat/[a-z0-9-]+\.webp$').hasMatch(value)) {
        throw const FormatException('Invalid/restricted RepDB image path.');
      }
      return value;
    }

    final translatedName = arabic?['name_ar'] as String? ?? '';
    return ExerciseCatalogItem(
      id: 'repdb:$sourceId',
      sourceId: sourceId,
      nameEn: _requiredString(json, 'name_en'),
      nameAr: translatedName,
      muscleGroup: _requiredString(json, 'body_part'),
      equipment: json['equipment'] as String? ?? '',
      category: json['category'] as String?,
      forceType: json['force_type'] as String?,
      mechanic: json['mechanic'] as String?,
      difficulty: json['difficulty'] as String?,
      variationGroup: json['variation_group'] as String?,
      isBodyweight: json['is_bodyweight'] == true,
      isUnilateral: json['is_unilateral'] == true,
      primaryMuscles: strings(json['primary_muscles'], 'primary muscles'),
      secondaryMuscles: strings(json['secondary_muscles'], 'secondary muscles'),
      instructionsEn: strings(json['instructions_en'], 'English instructions'),
      instructionsAr: arabic?['review_status'] == 'reviewed'
          ? strings(arabic?['instructions_ar'], 'Arabic instructions')
          : const [],
      tipsEn: strings(json['tips_en'], 'English tips'),
      tipsAr: arabic?['tips_review_status'] == 'reviewed'
          ? strings(arabic?['tips_ar'], 'Arabic tips')
          : const [],
      startImage: image('start'),
      peakImage: image('peak'),
      mainImage: image('main'),
      datasetVersion: datasetVersion,
      sourceAttribution: 'Exercise data by RepDB (repdb.co)',
      arabicNeedsReview: arabic?['review_status'] != 'reviewed',
    );
  }

  factory ExerciseCatalogItem.fromJson(Map<String, dynamic> json) {
    return ExerciseCatalogItem(
      id: _requiredString(json, 'id'),
      nameEn: _requiredString(json, 'name_en'),
      nameAr: _requiredString(json, 'name_ar'),
      muscleGroup: _requiredString(json, 'muscle_group'),
      equipment: _requiredString(json, 'equipment'),
    );
  }

  String nameForLanguage(String languageCode) =>
      languageCode.toLowerCase().startsWith('ar') && nameAr.isNotEmpty
      ? nameAr
      : nameEn;

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException(
        'Exercise catalog field "$key" must be a non-empty string.',
      );
    }
    return value;
  }
}
