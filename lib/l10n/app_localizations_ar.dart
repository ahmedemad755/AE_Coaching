// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get activeSessionOnly => 'هذه الجلسة فقط';

  @override
  String get activeSessionAndProgram => 'هذه الجلسة + البرنامج';

  @override
  String get activeExerciseScopeBody =>
      'حدّث التمرين الحالي فورًا. يتغير يوم البرنامج أيضًا فقط عند اختيار الجلسة + البرنامج.';

  @override
  String get activeApplyEdit => 'تطبيق';

  @override
  String get activeSessionEditSaved => 'تم تحديث الجلسة دون تغيير البرنامج.';

  @override
  String get activeProgramEditSaved => 'تم تحديث الجلسة ويوم البرنامج.';

  @override
  String get activeLoggedExerciseProtected =>
      'لهذا التمرين مجموعات مسجلة. احتفظ به لحماية سجلك وأضف تمرينًا آخر بدلًا منه. يمكنك تعديل الأهداف والترتيب.';

  @override
  String get activeProgramConflict =>
      'يختلف يوم البرنامج عن هذه الجلسة. اختر هذه الجلسة فقط، أو طبّق تمارين البرنامج قبل تعديل الاثنين.';

  @override
  String get activeProgramPending =>
      'تم حفظ تغييرات الجلسة، لكن تحديث البرنامج لم يكتمل. أعد المحاولة لإكماله. إيقاف المحاولات يحتفظ بالجلسة وأي تغيير تم حفظه بالفعل في البرنامج.';

  @override
  String get activeDuplicateExercise =>
      'هذا التمرين موجود بالفعل. لم تتم إضافة نسخة مكررة.';

  @override
  String get activeWorkoutNoLongerActive =>
      'لم تعد هذه الجلسة نشطة. أعد فتح تمرينك الحالي.';

  @override
  String get activeApplyProgram => 'تطبيق تمارين البرنامج';

  @override
  String get activeApplyProgramBody =>
      'تعديلات البرنامج من خارج الجلسة تخص التمارين القادمة فقط. هل تريد تطبيق يوم البرنامج الحالي على هذه الجلسة الآن؟ سيستبدل ذلك تعديلات تمارين الجلسة وأهدافها. تبقى المجموعات المسجلة محفوظة، ويُمنع أي تغيير يحذف تمرينًا له مجموعات مسجلة.';

  @override
  String get activeRetryProgramEdit => 'إعادة محاولة تحديث البرنامج';

  @override
  String get activeKeepSessionEdit => 'الاحتفاظ بالتغييرات وإيقاف المحاولات';

  @override
  String get appearanceTitle => 'المظهر';

  @override
  String get themeSystemDefault => 'حسب إعداد الجهاز';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'داكن';

  @override
  String get themePreferenceSaveError => 'تعذر حفظ تفضيل المظهر.';

  @override
  String get appBrandShort => 'AE';

  @override
  String get appBrandFull => 'AE COACHING';

  @override
  String get cancel => 'إلغاء';

  @override
  String get delete => 'حذف';

  @override
  String get save => 'حفظ';

  @override
  String get close => 'إغلاق';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get edit => 'تعديل';

  @override
  String get languageToggleTooltip => 'تغيير اللغة';

  @override
  String get inactivityRemindersTitle => 'تذكيرات الانقطاع عن التمرين';

  @override
  String get inactivityReminderSaveFailed =>
      'تعذر حفظ إعداد التنبيهات. حاول مجددًا.';

  @override
  String get inactivityRemindersSubtitle =>
      'تذكير لطيف لما تغيب عن تسجيل تمرينك لفترة.';

  @override
  String get inactivityReminderLoading => 'جارٍ تحميل إعداد التذكير…';

  @override
  String get inactivityReminderSaving => 'جارٍ حفظ إعداد التذكير…';

  @override
  String get inactivityReminderSaved => 'تم حفظ إعداد التذكير.';

  @override
  String get inactivityReminderSavedOffline =>
      'تم الحفظ على هذا الجهاز، وسيتم رفعه عند عودة الاتصال.';

  @override
  String get inactivityReminderPendingSync =>
      'في انتظار المزامنة. لم يتم تأكيد التغيير بعد.';

  @override
  String get inactivityReminderOffline =>
      'أنت غير متصل. اتصل بالإنترنت لتحميل إعداد التذكير.';

  @override
  String get inactivityReminderUnavailable =>
      'أكّد بريدك الإلكتروني لإدارة تذكيرات التمرين.';

  @override
  String get inactivityReminderLoadFailed => 'تعذر تحميل إعداد التذكير.';

  @override
  String get repdbInstructions => 'طريقة الأداء';

  @override
  String get repdbPrimaryMuscles => 'العضلات الأساسية';

  @override
  String get repdbSecondaryMuscles => 'العضلات المساعدة';

  @override
  String get repdbStartPosition => 'وضع البداية';

  @override
  String get repdbPeakPosition => 'وضع الانقباض أو النهاية';

  @override
  String get repdbDataSources => 'حقوق ومصادر بيانات التمارين';

  @override
  String get repdbSourceLicense => 'ترخيص RepDB المجاني';

  @override
  String get repdbTranslationPending =>
      'الترجمة العربية لطريقة الأداء قيد المراجعة. تُعرض تعليمات المصدر الإنجليزية أدناه.';

  @override
  String get repdbUnknownMetadata => 'غير مذكور في المصدر';

  @override
  String get repdbFormCues => 'إرشادات الأداء';

  @override
  String get repdbDatasetVersion => 'إصدار البيانات';

  @override
  String get repdbAddToWorkout => 'إضافة إلى التمرين';

  @override
  String get repdbLegacyReference =>
      'تمرين من المكتبة القديمة. يمكنك استبداله بتمرين من المكتبة الجديدة إذا أردت تحديثه.';

  @override
  String get repdbResolveBeforeSave =>
      'استبدل التمارين القديمة المتبقية قبل حفظ نسخة جديدة. تظل التمارين المحفوظة سابقًا كما هي.';

  @override
  String get homeGreetingMorning => 'صباح الخير';

  @override
  String get homeGreetingAfternoon => 'نهارك سعيد';

  @override
  String get homeGreetingEvening => 'مساء الخير';

  @override
  String get homeGreetingSubtitle => 'مستعد لتمرين اليوم؟';

  @override
  String get homeDashboardSubtitle => 'خطط وتمرّن وتابع تقدمك';

  @override
  String get homeManagePrograms => 'إدارة برامجك التدريبية';

  @override
  String get homeExploreTemplates => 'استكشف البرامج واحفظها';

  @override
  String get homeBeginSession => 'ابدأ جلسة تدريبية';

  @override
  String get homeProgress => 'التقدم';

  @override
  String get homeTrackResults => 'تابع نتائجك';

  @override
  String get homeQuickActions => 'إجراءات سريعة';

  @override
  String get homeLogWorkout => 'تسجيل تمرين';

  @override
  String get homeBodyMetrics => 'قياسات الجسم';

  @override
  String get homeNavigationHome => 'الرئيسية';

  @override
  String get homeNavigationPrograms => 'البرامج';

  @override
  String get homeNavigationMore => 'المزيد';

  @override
  String get loginSubtitle => 'تسجيل الدخول لحسابك';

  @override
  String get passwordHint => 'كلمة المرور';

  @override
  String get passwordRequired => 'من فضلك أدخل كلمة المرور';

  @override
  String get loginButton => 'تسجيل الدخول';

  @override
  String get forgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get registerNow => 'سجّل الآن';

  @override
  String get loginSuccessMessage => 'تم تسجيل الدخول بنجاح';

  @override
  String get genericSuccess => 'تم بنجاح';

  @override
  String get createAccountTitle => 'إنشاء حساب';

  @override
  String get startJourneySubtitle => 'ابدأ رحلتك التدريبية';

  @override
  String get fullNameHint => 'الاسم بالكامل';

  @override
  String get fullNameRequired => 'من فضلك أدخل اسمك';

  @override
  String get createAccountButton => 'إنشاء الحساب';

  @override
  String get completeRegistrationFinishProfileTitle => 'أكمل ملفك الشخصي';

  @override
  String get completeRegistrationFinishProfileSubtitle =>
      'محتاجين اسمك بس عشان نخلّص إعداد حسابك.';

  @override
  String get sessionCheckingMessage => 'جاري التحقق من حسابك...';

  @override
  String get forgotPasswordTitle => 'إعادة تعيين كلمة المرور';

  @override
  String get confirmPasswordHint => 'تأكيد كلمة المرور';

  @override
  String get confirmPasswordRequired => 'من فضلك أكّد كلمة المرور';

  @override
  String get passwordsDoNotMatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get passwordChangedSuccessMessage => 'تم تغيير كلمة المرور بنجاح';

  @override
  String get workoutTrackerSubtitle => 'متابعة التمرين';

  @override
  String get logoutTooltip => 'تسجيل الخروج';

  @override
  String get logoutConfirmTitle => 'تسجيل الخروج';

  @override
  String get logoutConfirmBody => 'متأكد إنك عايز تسجّل خروج من حسابك؟';

  @override
  String get measurementsTooltip => 'القياسات';

  @override
  String get progressAnalyticsTooltip => 'تحليل التقدم';

  @override
  String get startFirstExercise => 'ابدأ بإضافة أول تمرين ليك.';

  @override
  String get todaysVolumeLabel => 'حجم تمرين النهاردة: [كجم]';

  @override
  String get historyLabel => 'السجل';

  @override
  String get analyticsLabel => 'التحليلات';

  @override
  String get progressAnalyticsTitle => 'تحليل التقدم';

  @override
  String get exerciseTrendsLabel => 'اتجاهات التمرين';

  @override
  String get progressSelectProgram => 'البرنامج';

  @override
  String get progressSelectWorkoutDay => 'يوم التمرين';

  @override
  String get progressSelectExercise => 'التمرين';

  @override
  String get progressNoCompletedHistory =>
      'لا يوجد سجل مرتبط لتمارين مكتملة حتى الآن.';

  @override
  String get needMoreDataForProgress =>
      'ضيف يومين تمرين على الأقل عشان تفتح تحليل التقدم.';

  @override
  String exerciseNeedsMoreData(String name) {
    return '$name محتاج بيانات أكتر (تمرينين أو أكتر)';
  }

  @override
  String lastPreviousVolume(String current, String previous) {
    return 'آخر: $current كجم | السابق: $previous كجم';
  }

  @override
  String totalVolumeLabel(String date, String volume) {
    return '$date | إجمالي الحجم: $volume كجم';
  }

  @override
  String get addNewExerciseTitle => 'إضافة تمرين جديد';

  @override
  String addSetToTitle(String name) {
    return 'إضافة مجموعة لـ $name';
  }

  @override
  String editSetTitle(String name) {
    return 'تعديل مجموعة $name';
  }

  @override
  String get updateButton => 'تحديث';

  @override
  String get exerciseNameHint => 'اسم التمرين';

  @override
  String get weightKgHint => 'الوزن (كجم)';

  @override
  String get repsHint => 'التكرارات';

  @override
  String get addAnotherSetButton => 'إضافة مجموعة تانية';

  @override
  String get setsColumnLabel => 'المجموعات';

  @override
  String get weightColumnLabel => 'الوزن';

  @override
  String get repsColumnLabel => 'التكرارات';

  @override
  String get setLabel => 'مجموعة';

  @override
  String get deleteExerciseTitle => 'حذف التمرين';

  @override
  String deleteExerciseBody(String name, int count, String unit) {
    return 'متأكد إنك عايز تمسح $name و $count $unit بتوعه؟';
  }

  @override
  String get setUnitSingular => 'مجموعة';

  @override
  String get setUnitPlural => 'مجموعات';

  @override
  String get todaysProgressLabel => 'تقدم النهاردة';

  @override
  String get totalTrainingVolumeLabel => 'إجمالي حجم التمرين';

  @override
  String get trackedViaFooter =>
      'بيتم المتابعة بسهولة عبر تطبيق AE Coaching 🚀';

  @override
  String get shareProgressButton => 'مشاركة التقدم';

  @override
  String get sharingButton => 'جاري المشاركة...';

  @override
  String get bodyMeasurementsTitle => 'قياسات الجسم';

  @override
  String get addMeasurementButton => 'إضافة قياس';

  @override
  String get somethingWrongLoadingMeasurements =>
      'حصلت مشكلة أثناء تحميل قياساتك.';

  @override
  String get lastCheckInLabel => 'آخر قياس';

  @override
  String get historyButton => 'السجل';

  @override
  String get analyticsButton => 'التحليلات';

  @override
  String get noMeasurementsYetTitle => 'مفيش قياسات لسه.';

  @override
  String get addFirstCheckInSubtitle =>
      'ضيف أول قياس ليك عشان تبدأ تتابع تقدمك.';

  @override
  String get editMeasurementTitle => 'تعديل القياس';

  @override
  String get addMeasurementTitle => 'إضافة قياس';

  @override
  String get allFieldsOptionalHint =>
      'كل الحقول اختيارية — املا اللي قسته النهاردة بس.';

  @override
  String get changeDateButton => 'تغيير التاريخ';

  @override
  String get enterAtLeastOneMeasurement =>
      'أدخل قياس واحد على الأقل عشان تحفظ.';

  @override
  String get updateCheckInButton => 'تحديث القياس';

  @override
  String get saveCheckInButton => 'حفظ القياس';

  @override
  String get cmUnit => 'سم';

  @override
  String get measurementHistoryTitle => 'سجل القياسات';

  @override
  String get deleteCheckInTitle => 'حذف القياس';

  @override
  String deleteCheckInBody(String date) {
    return 'متأكد إنك عايز تمسح القياس بتاع $date؟';
  }

  @override
  String get unableToLoadHistory => 'تعذّر تحميل سجل القياسات.';

  @override
  String get noMeasurementsHistoryEmpty =>
      'مفيش قياسات لسه.\n\nضيف أول قياس ليك عشان تبدأ تتابع تقدمك.';

  @override
  String get measurementAnalyticsTitle => 'تحليل القياسات';

  @override
  String get unableToLoadAnalytics => 'تعذّر تحميل تحليل القياسات.';

  @override
  String get notEnoughDataYet => 'مفيش بيانات كافية لسه';

  @override
  String get sincePreviousCheckIn => 'منذ آخر قياس';

  @override
  String get overallProgress => 'التقدم الكلي';

  @override
  String get previousLabel => 'السابق';

  @override
  String get currentLabel => 'الحالي';

  @override
  String get firstLabel => 'الأول';

  @override
  String get latestLabel => 'الأحدث';

  @override
  String get noMeasurementsRecordedCheckIn =>
      'مفيش قياسات مسجّلة في القياس ده.';

  @override
  String get fieldChest => 'الصدر';

  @override
  String get fieldWaist => 'الخصر';

  @override
  String get fieldHips => 'الأرداف';

  @override
  String get fieldShoulders => 'الأكتاف';

  @override
  String get fieldNeck => 'الرقبة';

  @override
  String get fieldRightArm => 'الذراع اليمين';

  @override
  String get fieldLeftArm => 'الذراع الشمال';

  @override
  String get fieldRightThigh => 'الفخد اليمين';

  @override
  String get fieldLeftThigh => 'الفخد الشمال';

  @override
  String get fieldRightCalf => 'السمانة اليمين';

  @override
  String get fieldLeftCalf => 'السمانة الشمال';

  @override
  String get progressPhotosTitle => 'صور المتابعة';

  @override
  String get photosButton => 'الصور';

  @override
  String get addPhotoButton => 'إضافة صورة';

  @override
  String get choosePhotoSourceTitle => 'إضافة صورة متابعة';

  @override
  String get cameraOption => 'الكاميرا';

  @override
  String get galleryOption => 'معرض الصور';

  @override
  String get sinceLatestPhoto => 'منذ آخر صورة';

  @override
  String get beforeLabel => 'قبل';

  @override
  String get afterLabel => 'بعد';

  @override
  String get noPhotosYetTitle => 'مفيش صور متابعة لسه.';

  @override
  String get addFirstPhotoSubtitle => 'ضيف أول صورة ليك عشان تبدأ تقارن تطورك.';

  @override
  String get photoHistoryTitle => 'سجل الصور';

  @override
  String get deletePhotoTitle => 'حذف الصورة';

  @override
  String deletePhotoBody(String date) {
    return 'متأكد إنك عايز تمسح الصورة دي بتاريخ $date؟';
  }

  @override
  String get addPhotoPromptTitle => 'تحب تضيف صورة متابعة؟';

  @override
  String get addPhotoPromptBody => 'عايز تضيف صورة لنتيجة النهاردة؟';

  @override
  String get skip => 'تخطي';

  @override
  String get unableToLoadPhotos => 'تعذّر تحميل صور المتابعة.';

  @override
  String get myProgramsTitle => 'برامجي';

  @override
  String get activeProgramLabel => 'البرنامج النشط';

  @override
  String get previousProgramsLabel => 'البرامج السابقة';

  @override
  String get createProgramButton => 'إنشاء برنامج';

  @override
  String get createProgramTitle => 'إنشاء برنامج';

  @override
  String get programNameHint => 'اسم البرنامج';

  @override
  String get descriptionOptionalHint => 'الوصف (اختياري)';

  @override
  String get createButton => 'إنشاء';

  @override
  String get createAndMakeActiveButton => 'إنشاء وتفعيل';

  @override
  String get makeActiveButton => 'تفعيل';

  @override
  String get renameButton => 'إعادة تسمية';

  @override
  String get renameProgramTitle => 'إعادة تسمية البرنامج';

  @override
  String get archiveButton => 'أرشفة';

  @override
  String get openButton => 'فتح';

  @override
  String get noProgramsYetTitle => 'مفيش برامج لسه.';

  @override
  String get noProgramsYetSubtitle =>
      'أنشئ أول برنامج ليك عشان تبدأ تنظّم تدريبك.';

  @override
  String get makeActiveConfirmTitle => 'تفعيل البرنامج؟';

  @override
  String makeActiveConfirmBodyWithCurrent(String name) {
    return 'تحب تفعّل \"$name\"؟ برنامجك الحالي هيفضل محفوظ كبرنامج سابق.';
  }

  @override
  String makeActiveConfirmBodyNoCurrent(String name) {
    return 'تحب تفعّل \"$name\"؟';
  }

  @override
  String get archiveActiveConfirmTitle => 'أرشفة البرنامج؟';

  @override
  String archiveActiveConfirmBody(String name) {
    return 'تحب تؤرشف \"$name\"؟ هينتقل لقائمة البرامج السابقة — سجل تمرينك هيفضل زي ما هو.';
  }

  @override
  String get enterProgramNameValidation => 'أدخل اسم البرنامج.';

  @override
  String get unableToLoadProgramsError => 'تعذّر تحميل برامجك.';

  @override
  String get workoutDaysPlaceholder => 'أيام التمرين هتتضاف في المرحلة الجاية.';

  @override
  String get startedLabel => 'بدأ';

  @override
  String get endedLabel => 'انتهى';

  @override
  String get workoutProgramsTooltip => 'برامجي';

  @override
  String get workoutDaysTitle => 'أيام التمرين';

  @override
  String get addWorkoutDayButton => 'إضافة يوم تمرين';

  @override
  String get manageTemplateExercisesButton => 'إدارة التمارين';

  @override
  String manageTemplateExercisesTitle(String name) {
    return 'تمارين $name';
  }

  @override
  String get searchExerciseLibraryHint => 'ابحث عن تمرين';

  @override
  String get assignedTemplateExercisesTitle => 'خطة التمرين';

  @override
  String assignedTemplateExercisesCount(int count) {
    return 'التمارين · $count';
  }

  @override
  String get noAssignedTemplateExercises =>
      'لم تتم إضافة تمارين بعد. أضف التمارين هنا لتكون جاهزة كلما بدأت يوم التمرين ده.';

  @override
  String get exerciseLibraryTitle => 'مكتبة التمارين';

  @override
  String get noExerciseSearchResults => 'لا توجد تمارين مطابقة للبحث.';

  @override
  String get removeAssignedExerciseTooltip => 'إزالة التمرين من يوم التدريب';

  @override
  String get addAssignedExerciseTooltip => 'إضافة التمرين إلى يوم التدريب';

  @override
  String get templateExerciseDuplicateError => 'هذا التمرين مضاف بالفعل.';

  @override
  String get templateExerciseSaveError => 'تعذر حفظ تمارين يوم التدريب.';

  @override
  String get exerciseLibraryLoadError => 'تعذر تحميل مكتبة التمارين.';

  @override
  String get createWorkoutDayTitle => 'إضافة يوم تمرين';

  @override
  String get renameWorkoutDayTitle => 'إعادة تسمية يوم التمرين';

  @override
  String get workoutDayNameHint => 'اسم يوم التمرين';

  @override
  String get noWorkoutDaysYetTitle => 'مفيش أيام تمرين لسه.';

  @override
  String get noWorkoutDaysYetSubtitle =>
      'ضيف يوم تمرين زي \"Push 1\" عشان تبدأ تبني البرنامج ده.';

  @override
  String get archiveWorkoutDayConfirmTitle => 'أرشفة يوم التمرين؟';

  @override
  String archiveWorkoutDayConfirmBody(String name) {
    return 'تحب تؤرشف \"$name\"؟ هيتخفي من القايمة دي، بس سجل التمرين هيفضل زي ما هو.';
  }

  @override
  String get enterWorkoutDayNameValidation => 'أدخل اسم يوم التمرين.';

  @override
  String get unableToLoadWorkoutDaysError => 'تعذّر تحميل أيام التمرين.';

  @override
  String get startWorkoutButton => 'ابدأ التمرين';

  @override
  String get moveUpTooltip => 'تحريك لأعلى';

  @override
  String get moveDownTooltip => 'تحريك لأسفل';

  @override
  String get startWorkoutComingSoon => 'بدء التمرين هييجي في المرحلة الجاية.';

  @override
  String get resumeWorkoutBannerTitle => 'في تمرين شغال';

  @override
  String resumeWorkoutBannerBody(String name, String elapsed) {
    return '$name — بدأ من $elapsed';
  }

  @override
  String get resumeWorkoutButton => 'استكمال التمرين';

  @override
  String get workoutInProgressConflictTitle => 'فيه تمرين شغال بالفعل';

  @override
  String workoutInProgressConflictBody(String name) {
    return 'عندك بالفعل \"$name\" شغال. خلّصه أو ألغيه قبل ما تبدأ تمرين جديد.';
  }

  @override
  String get cancelWorkoutButton => 'إلغاء التمرين';

  @override
  String get cancelWorkoutConfirmTitle => 'تحب تلغي التمرين ده؟';

  @override
  String get cancelWorkoutConfirmBody =>
      'التمرين ده هيتسجل كـ ملغي ومش هيتحسب في سجلك. الإجراء ده مش قابل للتراجع.';

  @override
  String get finishWorkoutButton => 'إنهاء التمرين';

  @override
  String get finishWorkoutComingSoon =>
      'إنهاء التمرين هييجي في المرحلة الجاية.';

  @override
  String get elapsedTimeLabel => 'الوقت المنقضي';

  @override
  String get unableToStartWorkoutError => 'تعذّر بدء التمرين.';

  @override
  String get sessionExercisesTitle => 'التمارين';

  @override
  String get noExercisesLoggedYetBody =>
      'لسه مفيش تمارين متسجلة. دوس على \"تمرين جديد\" عشان تسجل أول مجموعة.';

  @override
  String get suggestedFromLastTimeLabel => 'مقترح من آخر مرة';

  @override
  String get logFirstSetButton => 'سجّل المجموعة';

  @override
  String get addSetTooltip => 'أضف مجموعة تانية';

  @override
  String get deleteSetTooltip => 'احذف المجموعة';

  @override
  String get unableToLogSetError => 'تعذّر تسجيل المجموعة.';

  @override
  String get exerciseNameRequiredError => 'من فضلك اكتب اسم التمرين.';

  @override
  String get lastTimeLabel => 'آخر مرة';

  @override
  String get finishWorkoutConfirmTitle => 'تنهي التمرين ده؟';

  @override
  String finishWorkoutConfirmBody(String volume) {
    return 'إجمالي الحجم المسجَّل: $volume كجم. ده هيسجل التمرين كمكتمل ويحفظه في سجلك.';
  }

  @override
  String get discardEmptyWorkoutTitle => 'تحب تلغي التمرين الفاضي؟';

  @override
  String get discardEmptyWorkoutBody =>
      'مفيش أي مجموعة مكتملة اتسجلت. كمل تمرينك أو الغي التمرين؟';

  @override
  String get keepTrainingButton => 'كمل التمرين';

  @override
  String get discardWorkoutButton => 'إلغاء التمرين';

  @override
  String get workoutCelebrationHeading => 'عاش يا بطل! 💪🔥';

  @override
  String get workoutCelebrationSubtitle =>
      'خلصت تمرينك بنجاح. كل تمرينة بتقربك من هدفك!';

  @override
  String get completionExercisesLabel => 'التمارين';

  @override
  String get completionSetsLabel => 'المجموعات';

  @override
  String get completionVolumeLabel => 'الحجم التدريبي';

  @override
  String get workoutDurationLabel => 'المدة';

  @override
  String completionDurationMinutes(int minutes) {
    return '$minutes دقيقة';
  }

  @override
  String get backToHomeButton => 'العودة للرئيسية';

  @override
  String workoutFinishedBody(String volume) {
    return 'التمرين خلص! إجمالي الحجم: $volume كجم.';
  }

  @override
  String get unableToFinishWorkoutError => 'تعذّر إنهاء التمرين.';

  @override
  String get workoutSummaryTitle => 'ملخص التمرين';

  @override
  String get sessionTotalVolumeLabel => 'إجمالي الحجم';

  @override
  String get sinceLastTimeLabel => 'مقارنة بآخر مرة';

  @override
  String get noPreviousSessionBody =>
      'لسه مفيش تمرين سابق لليوم ده — المرة الجاية هتشوف مقارنة أدائك.';

  @override
  String get newPersonalRecordsLabel => 'أرقام قياسية جديدة';

  @override
  String firstTimePrBody(String exercise) {
    return 'أول مرة تسجل $exercise!';
  }

  @override
  String heaviestWeightPrBody(String exercise, String weight, String previous) {
    return '$exercise: أتقل وزن على الإطلاق — $weight كجم (كان $previous كجم)';
  }

  @override
  String highestSetVolumePrBody(String exercise, String weight, int reps) {
    return '$exercise: أفضل مجموعة على الإطلاق — $weight كجم × $reps';
  }

  @override
  String get exerciseImprovedLabel => 'تحسّن';

  @override
  String get exerciseMaintainedLabel => 'ثابت';

  @override
  String get exerciseDeclinedLabel => 'قلّ';

  @override
  String get exerciseNewLabel => 'جديد';

  @override
  String get doneButton => 'تم';

  @override
  String workoutHistoryTitle(String name) {
    return 'سجل $name';
  }

  @override
  String get historyTooltip => 'السجل';

  @override
  String get noSessionsYetTitle => 'لسه مفيش جلسات';

  @override
  String get noSessionsYetSubtitle =>
      'خلّص تمرين لليوم ده عشان يبدأ سجله يتكوّن.';

  @override
  String get sessionCompletedLabel => 'مكتمل';

  @override
  String get sessionCancelledLabel => 'ملغي';

  @override
  String get sessionInProgressLabel => 'جاري';

  @override
  String get sessionDurationLabel => 'المدة';

  @override
  String get viewWorkoutTrackerButton => 'افتح متتبع التمرين';

  @override
  String get programAnalyticsTitle => 'تحليلات البرنامج';

  @override
  String get analyticsSelectDay => 'يوم التمرين';

  @override
  String get analyticsSelectExercise => 'التمرين';

  @override
  String get analyticsWeightTitle => 'تطور الوزن';

  @override
  String get analyticsRepsTitle => 'تطور التكرارات';

  @override
  String get analyticsVolumeTitle => 'تطور حجم التدريب';

  @override
  String get analyticsRepsUnit => 'تكرار';

  @override
  String get analyticsVolumeUnit => 'كجم × تكرار';

  @override
  String analyticsRepsAtWeight(String weight) {
    return 'أفضل تكرارات عند $weight كجم';
  }

  @override
  String analyticsPreviousValue(String date, String value, String unit) {
    return 'السابق ($date): $value $unit';
  }

  @override
  String analyticsLatestValue(String date, String value, String unit) {
    return 'الأحدث ($date): $value $unit';
  }

  @override
  String analyticsAbsoluteChange(String change, String unit) {
    return 'التغير: $change $unit';
  }

  @override
  String analyticsPercentChange(String change) {
    return 'التغير: $change%';
  }

  @override
  String get analyticsPercentageUnavailable =>
      'لا يمكن حساب النسبة لأن القيمة السابقة تساوي صفرًا.';

  @override
  String get analyticsNeedMoreSessions =>
      'أكمل جلستين على الأقل لهذا التمرين لمقارنة التطور.';

  @override
  String get analyticsNoComparableReps =>
      'لا يوجد وزن مشترك في آخر جلستين، لذلك لا يمكن مقارنة التكرارات.';

  @override
  String get analyticsTooltip => 'التحليلات';

  @override
  String get noAnalyticsYetTitle => 'لسه مفيش بيانات';

  @override
  String get noAnalyticsYetSubtitle =>
      'خلّص كام تمرين عشان تبدأ تشوف اتجاه أدائك هنا.';

  @override
  String sessionsLoggedLabel(int count) {
    return '$count جلسة';
  }

  @override
  String get averageVolumeLabel => 'متوسط الحجم';

  @override
  String get bestWeightLabel => 'الأفضل';

  @override
  String get noExercisesForDayYetBody => 'لسه مفيش جلسات مكتملة لليوم ده.';

  @override
  String get thisWeekTitle => 'الأسبوع ده';

  @override
  String totalSessionsThisWeekLabel(int count) {
    return '$count جلسة مكتملة';
  }

  @override
  String templateSessionsThisWeekLabel(int count) {
    return '$count×';
  }

  @override
  String get restTimerLabel => 'تايمر الراحة';

  @override
  String get restDurationLabel => 'مدة الراحة';

  @override
  String get restMinutesLabel => 'دقيقة';

  @override
  String get restSecondsLabel => 'ثانية';

  @override
  String get setDoneLabel => 'تم';

  @override
  String get waitForRestTimerLabel => 'انتظر حتى ينتهي وقت الراحة.';

  @override
  String get markPreviousSetDoneLabel =>
      'علّم المجموعة السابقة بأنها تمت لبدء الراحة.';

  @override
  String get startRestTimerButton => 'ابدأ';

  @override
  String get stopRestTimerButton => 'وقف';

  @override
  String get resetRestTimerTooltip => 'تصفير';

  @override
  String get setNotesHint => 'ملاحظات (اختياري)';

  @override
  String get sessionNoteTooltip => 'ملاحظة الجلسة';

  @override
  String get editSessionNoteTitle => 'ملاحظة الجلسة';

  @override
  String get sessionNoteHint => 'التمرين ده كان حاسس بيه إزاي؟';

  @override
  String get saveNoteButton => 'حفظ';

  @override
  String get unableToSaveNoteError => 'تعذّر حفظ الملاحظة.';

  @override
  String get consistencyTitle => 'الانتظام';

  @override
  String get currentWeekStreakLabel => 'التتابع الحالي';

  @override
  String weeksUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أسابيع',
      one: 'أسبوع',
    );
    return '$count $_temp0';
  }

  @override
  String get longestWeekStreakLabel => 'أطول تتابع';

  @override
  String get averagePerWeekLabel => 'متوسط أسبوعي';

  @override
  String get daysSinceLastSessionLabel => 'آخر تمرين';

  @override
  String daysAgoLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أيام',
      two: 'يومين',
      one: 'يوم',
      zero: 'يوم',
    );
    return 'من $count $_temp0';
  }

  @override
  String get noConsistencyDataYetBody =>
      'خلّص كام تمرين عشان تشوف انتظامك هنا.';

  @override
  String get kgUnit => 'كجم';

  @override
  String currentVsPreviousVolumeLabel(String current, String previous) {
    return '$current كجم ($previous كجم آخر مرة)';
  }

  @override
  String durationHoursMinutesLabel(int hours, int minutes) {
    return '$hoursس $minutesد';
  }

  @override
  String durationMinutesOnlyLabel(int minutes) {
    return '$minutesد';
  }

  @override
  String durationSecondsOnlyLabel(int seconds) {
    return '$secondsث';
  }

  @override
  String exerciseBestLatestSummary(String bestWeight, String latestVolume) {
    return 'أفضل: $bestWeight كجم  •  $latestVolume كجم آخر مرة';
  }

  @override
  String get homeCurrentProgramLabel => 'البرنامج الحالي';

  @override
  String get homeWorkoutPlansTitle => 'خطط التمرين';

  @override
  String get homeViewAllPlansButton => 'عرض الكل';

  @override
  String get homeNoWorkoutPlansBody => 'أنشئ أول خطة تمرين لتنظيم أيام تمرينك.';

  @override
  String get homeCreateWorkoutPlanButton => 'إنشاء خطة تمرين';

  @override
  String homeWorkoutsCompletedThisWeekLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تمارين مكتملة',
      two: 'تمرينين مكتملين',
      one: 'تمرين مكتمل',
      zero: 'تمرين مكتمل',
    );
    return '$count $_temp0';
  }

  @override
  String get homeOpenProgramButton => 'افتح البرنامج';

  @override
  String get homeWorkoutInProgressLabel => 'تمرين جاري';

  @override
  String homeStartedAgoLabel(String duration) {
    return 'بدأ من $duration';
  }

  @override
  String get homeRecentWorkoutsTitle => 'التمارين الأخيرة';

  @override
  String homeExerciseCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تمارين',
      two: 'تمرينين',
      one: 'تمرين',
    );
    return '$count $_temp0';
  }

  @override
  String homeSetCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'مجموعات',
      two: 'مجموعتين',
      one: 'مجموعة',
    );
    return '$count $_temp0';
  }

  @override
  String homeTotalVolumeLabel(String volume) {
    return 'إجمالي الحجم: $volume كجم';
  }

  @override
  String get homeViewSessionButton => 'شوف الجلسة';

  @override
  String get homeShowExercisesButton => 'اعرض التمارين';

  @override
  String get homeHideExercisesButton => 'اخفِ التمارين';

  @override
  String get homeNoActiveProgramTitle => 'مفيش برنامج نشط';

  @override
  String get homeNoActiveProgramBody =>
      'اعمل أو فعّل برنامج عشان تبدأ تتابع تمارينك بشكل منظم.';

  @override
  String get homeNoRecentWorkoutsBody => 'لسه مفيش تمارين مكتملة.';

  @override
  String get startWorkoutFabLabel => 'ابدأ تمرين';

  @override
  String get deleteProgramConfirmTitle => 'تحذف البرنامج ده نهائي؟';

  @override
  String deleteProgramConfirmBody(String name) {
    return 'ده هيحذف \"$name\" نهائيًا وكل حاجة جواه — كل يوم تمرين، وكل جلسة، وكل تمرين اتسجل. الإجراء ده مش قابل للتراجع.';
  }

  @override
  String get deleteWorkoutDayConfirmTitle => 'تحذف يوم التمرين ده نهائي؟';

  @override
  String deleteWorkoutDayConfirmBody(String name) {
    return 'ده هيحذف \"$name\" نهائيًا وكل حاجة جواه — كل جلسة، وكل تمرين اتسجل. الإجراء ده مش قابل للتراجع.';
  }

  @override
  String get archivedWorkoutDaysTooltip => 'الأرشيف';

  @override
  String get archivedWorkoutDaysTitle => 'أيام التمرين المؤرشفة';

  @override
  String get noArchivedWorkoutDaysBody => 'مفيش أيام تمرين مؤرشفة.';

  @override
  String get restoreButton => 'استرجاع';

  @override
  String get exercisePickerTitle => 'اختر التمارين';

  @override
  String get exerciseFiltersTitle => 'تصفية التمارين';

  @override
  String get muscleGroupLabel => 'المجموعة العضلية';

  @override
  String get equipmentLabel => 'المعدات';

  @override
  String get createCustomExerciseButton => 'إنشاء تمرين مخصص';

  @override
  String addSelectedExercisesButton(int count) {
    return 'إضافة المحدد ($count)';
  }

  @override
  String get customExerciseDuplicateError => 'يوجد تمرين بهذا الاسم بالفعل.';

  @override
  String get customExerciseSaveError => 'تعذر حفظ التمرين المخصص.';

  @override
  String get createCustomExerciseTitle => 'إنشاء تمرين مخصص';

  @override
  String get exerciseNameLabel => 'اسم التمرين';

  @override
  String get muscleGroupOptionalLabel => 'المجموعة العضلية (اختياري)';

  @override
  String get equipmentOptionalLabel => 'المعدات (اختياري)';

  @override
  String get addExerciseButton => 'إضافة تمرين';

  @override
  String get addExerciseToTitle => 'إضافة التمارين إلى';

  @override
  String get addExerciseToBody =>
      'اختر إضافة التمارين لهذا التمرين الحالي فقط، أو حفظها في يوم التمرين لاستخدامها لاحقًا.';

  @override
  String get currentSessionOnlyAction => 'التمرين الحالي فقط';

  @override
  String get saveToWorkoutDayAction => 'حفظ في يوم التمرين';

  @override
  String get exerciseLibrarySaveError => 'تعذرت إضافة التمارين المحددة.';

  @override
  String get newExerciseButton => 'إضافة تمرين';

  @override
  String get sessionOnlyExerciseLabel => 'مضاف لهذا التمرين الحالي فقط';

  @override
  String get replaceExerciseAction => 'استبدال التمرين';

  @override
  String get removeExerciseAction => 'إزالة التمرين';

  @override
  String get exerciseChangeDestinationTitle => 'أين تريد تطبيق التغيير؟';

  @override
  String get exerciseChangeDestinationBody =>
      'اختر تطبيقه على التمرين الحالي فقط أو حفظه في يوم التمرين للجلسات القادمة. الحفظ في يوم التمرين لا يغير الجلسة الحالية.';

  @override
  String get exerciseChangeFutureOnlyNote =>
      'حفظ التغيير في يوم التمرين يؤثر على الجلسات القادمة فقط، ولا يغير التمرين الحالي.';

  @override
  String removeExerciseLoggedSetsBody(Object name, int count) {
    return 'يحتوي $name على $count مجموعة مسجلة. إزالته تخفيه من قائمة هذه الجلسة فقط؛ وتظل المجموعات محفوظة في سجل التمرين والإجماليات.';
  }

  @override
  String get personalHubTitle => 'الملف الشخصي';

  @override
  String get profileHeaderSubtitle => 'تدريبك وبيانات حسابك في مكان واحد';

  @override
  String get profileEditName => 'تعديل الاسم';

  @override
  String get profileEmailLabel => 'البريد الإلكتروني';

  @override
  String get profileAddPhoto => 'إضافة صورة';

  @override
  String get profileChangePhoto => 'تغيير الصورة';

  @override
  String get profileRemovePhoto => 'إزالة الصورة';

  @override
  String get profilePhotoPreviewTitle => 'معاينة صورة الملف الشخصي';

  @override
  String get profilePhotoSaved => 'تم حفظ الصورة الشخصية.';

  @override
  String get profilePhotoRemoved => 'تمت إزالة الصورة الشخصية.';

  @override
  String get profilePhotoSaveFailed =>
      'تعذر حفظ صورة الملف الشخصي. جرّب صورة أخرى.';

  @override
  String get profilePhotoRemoveFailed =>
      'تعذرت إزالة صورة الملف الشخصي. حاول مجددًا.';

  @override
  String get profilePhotoRemoveConfirm =>
      'إزالة صورة الملف الشخصي فقط؟ سيظل حسابك وبيانات التمرين كما هي.';

  @override
  String get profileNameSaved => 'تم تحديث اسمك.';

  @override
  String get profileNameSaveFailed =>
      'تعذر تحديث الاسم. تحقق من الاتصال وحاول مجددًا.';

  @override
  String get profileProgressAction => 'تقدمي';

  @override
  String get appSettingsTitle => 'إعدادات التطبيق';

  @override
  String get myProgressTitle => 'تقدمي';

  @override
  String get progressCompletedWorkoutsLabel => 'التمارين المكتملة';

  @override
  String get progressThisWeekLabel => 'هذا الأسبوع';

  @override
  String get progressThisMonthLabel => 'هذا الشهر';

  @override
  String get progressWeeklyActivity => 'النشاط الأسبوعي';

  @override
  String get progressPersonalRecords => 'أرقامك القياسية';

  @override
  String get progressHeaviestWeightRecord => 'أثقل وزن';

  @override
  String get progressHighestSetVolumeRecord => 'أعلى حجم لمجموعة';

  @override
  String get progressProgramAnalytics => 'تحليلات البرامج';

  @override
  String get progressRecentWorkouts => 'سجل التمارين';

  @override
  String get progressNoCompletedWorkouts =>
      'ستظهر تمارينك هنا بعد إكمال أول تمرين.';

  @override
  String get progressDataUnavailable => 'تعذر تحميل تقدمك التدريبي الآن.';

  @override
  String get profileNameUnavailable => 'الاسم غير متاح';

  @override
  String get profileNameInvalid =>
      'اكتب اسمًا لا يزيد عن 60 حرفًا ويحتوي على حرف واحد على الأقل.';

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get settingsNotifications => 'الإشعارات والتذكيرات';

  @override
  String get settingsNotificationAuthorized => 'إشعارات الجهاز مسموح بها';

  @override
  String get settingsNotificationDenied => 'إشعارات الجهاز متوقفة';

  @override
  String get settingsNotificationNotRequested =>
      'لم يُطلب إذن إشعارات الجهاز بعد';

  @override
  String get settingsNotificationPermissionNote =>
      'مفتاح تذكير التمرين منفصل عن إذن الإشعارات في الهاتف.';

  @override
  String get settingsPermissionHelpAction => 'طريقة تفعيل الإشعارات';

  @override
  String get settingsPermissionHelpBody =>
      'افتح إعدادات الهاتف، ثم التطبيقات، واختر AE Coaching، وبعدها اسمح بالإشعارات.';

  @override
  String get settingsLogoutDescription =>
      'تسجيل الخروج من هذا الجهاز. ستظل تمارينك وبيانات حسابك محفوظة.';

  @override
  String get profileNameEditTitle => 'تعديل اسمك';

  @override
  String get exercisePickerAlternateTitle => 'Select Exercises';

  @override
  String get exerciseIllustrationUnavailable => 'الصورة غير متاحة بعد';

  @override
  String get exercisePreviewAction => 'معاينة التمرين';

  @override
  String get exerciseCustomBadge => 'مخصص';

  @override
  String get exerciseAllFilter => 'الكل';

  @override
  String get exerciseWatchVideo => 'شاهد على MuscleWiki (في المتصفح الخارجي)';

  @override
  String get exerciseBrowserLaunchFailed => 'تعذر فتح المتصفح. حاول مرة أخرى.';

  @override
  String get exerciseArtworkCredits => 'حقوق الرسم التوضيحي';

  @override
  String get exerciseArtworkSource => 'عرض مصدر الرسم التوضيحي';

  @override
  String get exerciseArtworkLicense => 'قراءة ترخيص الرسم دون إنترنت';

  @override
  String exerciseMuscleName(String muscle) {
    String _temp0 = intl.Intl.selectLogic(muscle, {
      'chest': 'الصدر',
      'back': 'الظهر',
      'shoulders': 'الأكتاف',
      'biceps': 'بايسبس',
      'triceps': 'ترايسبس',
      'quadriceps': 'الفخذ الأمامي',
      'hamstrings_glutes': 'الفخذ الخلفي / الأرداف',
      'calves': 'السمانة',
      'abs_core': 'البطن / الجذع',
      'full_body': 'الجسم بالكامل',
      'other': '$muscle',
    });
    return '$_temp0';
  }

  @override
  String exerciseEquipmentName(String equipment) {
    String _temp0 = intl.Intl.selectLogic(equipment, {
      'barbell': 'بار',
      'dumbbell': 'دمبل',
      'cable': 'كابل',
      'machine': 'جهاز',
      'bodyweight': 'وزن الجسم',
      'smith_machine': 'جهاز سميث',
      'ez_bar': 'بار متعرج',
      'kettlebell': 'كيتل بيل',
      'plate': 'قرص وزن',
      'trap_bar': 'بار سداسي',
      'ab_wheel': 'عجلة البطن',
      'other': '$equipment',
    });
    return '$_temp0';
  }

  @override
  String get workoutTemplatesTitle => 'قوالب التمارين';

  @override
  String get standardTemplatesIntro =>
      'اختر تقسيمة، واستعرض أيامها، ثم خصّص نسختك المستقلة.';

  @override
  String get useWorkoutTemplate => 'استخدم القالب';

  @override
  String get customizeTemplateTitle => 'تخصيص البرنامج';

  @override
  String get saveToMyPrograms => 'حفظ في برامجي';

  @override
  String get standardTemplateSaved => 'تم حفظ البرنامج في برامجي.';

  @override
  String get standardTemplateSavedLocally =>
      'تم حفظ البرنامج على هذا الجهاز. النسخ السحابي غير مكتمل؛ أعد فتح برامجي وأيام البرنامج عند الاتصال.';

  @override
  String get standardTemplateLoadError => 'تعذر تحميل قوالب التمارين.';

  @override
  String get standardTemplatesEmpty => 'لا توجد قوالب تمارين متاحة.';

  @override
  String get standardTemplateProgrammingNote =>
      'المجموعات الفعلية لا تشمل الإحماء. ابدأ بأوزان تتيح نحو ١–٣ تكرارات إضافية قبل العجز. قلّل الحجم عند الحاجة، وزد الوزن تدريجيًا ضمن نطاق التكرارات، وراعِ التعافي. يمكنك زيادة الراحة عند الحاجة. هذه خطط بداية قابلة للتعديل وليست وصفة فردية.';

  @override
  String get standardTemplateAdvancedNote =>
      'ستة أيام تدريب تناسب المتمرنين ذوي الخبرة والتعافي الكافي. جلسات أ/ب توزّع الحمل الأسبوعي وليست تكرارًا مضاعفًا لخطة الثلاثة أيام. أضف أيام راحة إذا تراجع التعافي.';

  @override
  String get standardTemplateAnteriorPosteriorNote =>
      'تقسيمة تركيز عملية: الأيام الأمامية للصدر والعضلات الأمامية للفخذ والأكتاف والبايسبس والبطن؛ والخلفية للظهر والخلفية للفخذ والجلوتس والأكتاف الخلفية والترايسبس والسمانة. يوجد تداخل طبيعي بين الحركات.';

  @override
  String get suggestedTrainingWeek => 'تسلسل مقترح لسبعة أيام';

  @override
  String get standardRestDay => 'راحة';

  @override
  String get workingSetsLabel => 'المجموعات الفعلية';

  @override
  String get minimumRepsLabel => 'أقل تكرارات';

  @override
  String get maximumRepsLabel => 'أعلى تكرارات';

  @override
  String get exerciseRestSecondsLabel => 'الراحة (ثوانٍ)';

  @override
  String get editExerciseTargets => 'تعديل المجموعات والتكرارات والراحة';

  @override
  String get exerciseTargetsValidation =>
      'استخدم ١–١٠ مجموعات، و١–١٠٠ تكرار (الأقل لا يتجاوز الأعلى)، و١٥–٦٠٠ ثانية راحة.';

  @override
  String get standardDraftInvalid =>
      'أدخل اسم البرنامج واسم كل يوم، واترك تمرينًا واحدًا على الأقل في كل يوم، وتحقق من أهداف التمارين.';

  @override
  String get standardDraftSaveError =>
      'تعذر حفظ البرنامج. مسودتك ما زالت متاحة؛ حاول مجددًا.';

  @override
  String get standardDraftAccountChanged =>
      'تم تغيير الحساب. أعد فتح قوالب التمارين للحساب الحالي.';

  @override
  String get discardProgramDraftTitle => 'تجاهل هذه المسودة؟';

  @override
  String get discardProgramDraftBody =>
      'لم يُحفظ هذا البرنامج. المغادرة ستتجاهل تخصيصاتك.';

  @override
  String get discardProgramDraft => 'تجاهل المسودة';

  @override
  String templateDaysPerWeek(int count) {
    return '$count أيام / أسبوع';
  }

  @override
  String suggestedSequenceDay(int day) {
    return 'اليوم $day';
  }

  @override
  String exerciseTargetSummary(int sets, int min, int max, int seconds) {
    return 'الخطة: $sets مجموعات × $min–$max تكرار · راحة $seconds ث';
  }

  @override
  String get loadingLabel => 'جارٍ التحميل';

  @override
  String resendCodeIn(int seconds) {
    return 'إعادة الإرسال بعد $seconds ث';
  }

  @override
  String get signOutUseAnotherAccount => 'تسجيل الخروج واستخدام حساب تاني';

  @override
  String get leaveVerificationTitle => 'عايز تسيب التحقق؟';

  @override
  String get signOutButton => 'تسجيل الخروج';

  @override
  String get stayButton => 'استنى';

  @override
  String get verificationInProgressMessage => 'استنى لحد ما التحقق يخلص.';

  @override
  String get sessionCheckFailedTitle => 'معرفناش نتحقق من حسابك';

  @override
  String get sessionCheckFailedBody => 'اتأكد من اتصال الإنترنت وحاول تاني.';

  @override
  String nameTooLong(int max) {
    return 'الاسم لازم يكون $max حرف أو أقل';
  }

  @override
  String get nameNeedsLetters => 'الاسم لازم يحتوي على حروف';

  @override
  String passwordMinLengthError(int min) {
    return 'كلمة المرور لازم تكون $min حروف على الأقل';
  }

  @override
  String passwordMaxLengthError(int max) {
    return 'كلمة المرور لازم تكون $max حرف أو أقل';
  }

  @override
  String get passwordEdgeWhitespaceError =>
      'كلمة المرور ماينفعش تبدأ أو تنتهي بمسافة';

  @override
  String passwordRequirementsHelper(int min) {
    return '$min حروف على الأقل';
  }

  @override
  String get showPasswordTooltip => 'إظهار كلمة المرور';

  @override
  String get hidePasswordTooltip => 'إخفاء كلمة المرور';

  @override
  String get changePasswordAction => 'تغيير كلمة المرور';

  @override
  String get authErrorWeakPassword =>
      'من فضلك اختار كلمة مرور أقوى (6 حروف على الأقل).';

  @override
  String get authErrorNetwork =>
      'مشكلة في الاتصال. اتأكد من الإنترنت وحاول تاني.';

  @override
  String get authErrorTooManyRequests => 'محاولات كتير. حاول تاني بعد شوية.';

  @override
  String get authErrorAccountDisabled =>
      'الحساب ده متوقف. من فضلك تواصل مع الدعم.';

  @override
  String get authErrorGeneric => 'حصلت مشكلة. حاول تاني.';

  @override
  String get authErrorInvalidName => 'من فضلك أدخل اسم صحيح.';

  @override
  String get emailHint => 'البريد الإلكتروني';

  @override
  String get emailRequired => 'من فضلك أدخل بريدك الإلكتروني';

  @override
  String get emailInvalidError => 'من فضلك أدخل بريد إلكتروني صحيح';

  @override
  String get emailTooLongError => 'البريد الإلكتروني طويل جدًا';

  @override
  String get emailReservedError => 'لا يمكن استخدام هذا البريد الإلكتروني';

  @override
  String get verifyEmailTitle => 'تأكيد البريد الإلكتروني';

  @override
  String verifyEmailBody(String email) {
    return 'أرسلنا رابط تأكيد إلى $email. افتح الرابط، ثم ارجع واضغط \"تم التأكيد\".';
  }

  @override
  String verifyEmailNotSentBody(String email) {
    return 'لم نتمكن من إرسال رسالة التأكيد إلى $email. اضغط إعادة الإرسال للمحاولة مرة أخرى.';
  }

  @override
  String get verifyEmailSpamHint =>
      'لا تجد الرسالة؟ تحقق من مجلد الرسائل غير المرغوب فيها (Spam).';

  @override
  String get iveVerifiedButton => 'تم التأكيد';

  @override
  String get resendEmailButton => 'إعادة إرسال الرسالة';

  @override
  String get verificationEmailSentMessage => 'تم إرسال رسالة التأكيد.';

  @override
  String get emailNotVerifiedYetMessage =>
      'لم يتم تأكيد بريدك الإلكتروني بعد. افتح الرابط الذي أرسلناه ثم حاول مرة أخرى.';

  @override
  String get changeEmailButton => 'تغيير البريد الإلكتروني';

  @override
  String get changeEmailBody =>
      'سنرسل رابط تأكيد إلى العنوان الجديد. يتغير بريد تسجيل الدخول بعد فتح الرابط.';

  @override
  String get newEmailHint => 'البريد الإلكتروني الجديد';

  @override
  String get sendLinkButton => 'إرسال الرابط';

  @override
  String emailChangeRequestedMessage(String email) {
    return 'تم إرسال رابط التأكيد إلى $email. افتحه لإتمام تغيير بريدك الإلكتروني.';
  }

  @override
  String get emailVerifiedSuccessMessage => 'تم تأكيد البريد الإلكتروني بنجاح';

  @override
  String get accountSetupCompleteMessage => 'تم إعداد الحساب بنجاح';

  @override
  String get legacyAccountSignedOutMessage =>
      'حساب التجربة هذا لم يعد مدعومًا. من فضلك أنشئ حسابًا جديدًا ببريدك الإلكتروني.';

  @override
  String get leaveEmailVerificationBody =>
      'سيتم تسجيل خروجك. يمكنك تسجيل الدخول مرة أخرى في أي وقت لإكمال تأكيد بريدك الإلكتروني.';

  @override
  String get forgotPasswordEmailSubtitle =>
      'أدخل البريد الإلكتروني لحسابك وسنرسل لك رابطًا لإعادة تعيين كلمة المرور.';

  @override
  String get sendResetLinkButton => 'إرسال رابط إعادة التعيين';

  @override
  String get passwordResetEmailSentTitle => 'تحقق من بريدك الإلكتروني';

  @override
  String passwordResetEmailSentBody(String email) {
    return 'إذا كان هناك حساب مرتبط بـ $email، فقد أرسلنا رابطًا لإعادة تعيين كلمة المرور.';
  }

  @override
  String get backToLoginButton => 'العودة لتسجيل الدخول';

  @override
  String get authErrorIncorrectEmailCredentials =>
      'البريد الإلكتروني أو كلمة المرور غير صحيحة.';

  @override
  String get authErrorEmailInUse =>
      'يوجد حساب بالفعل بهذا البريد الإلكتروني. من فضلك سجّل الدخول.';

  @override
  String get authErrorNewEmailInUse =>
      'هذا البريد الإلكتروني مستخدم بالفعل في حساب آخر.';

  @override
  String get authErrorRecentLoginEmail =>
      'لحمايتك، من فضلك سجّل الدخول مرة أخرى لتغيير بريدك الإلكتروني.';

  @override
  String get authErrorSessionExpired =>
      'انتهت صلاحية الجلسة. من فضلك سجّل الدخول مرة أخرى.';

  @override
  String get authErrorSessionEnded =>
      'انتهت الجلسة. من فضلك سجّل الدخول مرة أخرى.';

  @override
  String get accountSetupFailedTitle => 'لم نتمكن من إكمال إعداد حسابك';

  @override
  String get profilePermissionDeniedBody =>
      'تم رفض الوصول إلى ملف حسابك. حاول مرة أخرى لاحقًا، أو تواصل مع الدعم إذا استمرت المشكلة.';

  @override
  String get profileConflictingBody =>
      'ملف حسابك يحتاج إلى مراجعة. من فضلك تواصل مع الدعم.';

  @override
  String get profileUnknownFailureBody =>
      'حدث خطأ أثناء إعداد حسابك. حاول مرة أخرى.';

  @override
  String get authErrorProfilePermissionDenied =>
      'لم نتمكن من حفظ ملفك الشخصي لأنه تم رفض الوصول. من فضلك تواصل مع الدعم.';

  @override
  String get authErrorProfileConflicting =>
      'ملف حسابك يحتاج إلى مراجعة. من فضلك تواصل مع الدعم.';

  @override
  String get feedbackDismiss => 'إغلاق';

  @override
  String get feedbackSuccessLabel => 'تم بنجاح';

  @override
  String get feedbackErrorLabel => 'خطأ';

  @override
  String get feedbackWarningLabel => 'تنبيه';

  @override
  String get feedbackInfoLabel => 'معلومة';

  @override
  String get feedbackLoadingLabel => 'جارٍ التنفيذ';

  @override
  String get feedbackGenericError => 'حدث خطأ ما. حاول مرة أخرى.';

  @override
  String get feedbackSignInRequired =>
      'انتهت جلستك. يرجى تسجيل الدخول مرة أخرى.';

  @override
  String get feedbackItemUnavailable =>
      'هذا العنصر لم يعد متاحًا. حدّث الصفحة وحاول مرة أخرى.';

  @override
  String get logoutFailedMessage => 'تعذّر تسجيل الخروج. حاول مرة أخرى.';

  @override
  String get feedbackWorkoutNotActive => 'هذا التمرين لم يعد نشطًا.';

  @override
  String get dangerZoneTitle => 'منطقة الخطر';

  @override
  String get deleteAccountTitle => 'حذف الحساب';

  @override
  String get deleteAccountEntrySubtitle => 'حذف حسابك وبياناته نهائيًا';

  @override
  String get deleteAccountIntro => 'حذف حسابك يزيل نهائيًا:';

  @override
  String get deleteAccountItemWorkouts => 'تمارينك ومجموعاتك وجلساتك وبرامجك';

  @override
  String get deleteAccountItemMeasurements => 'مقاسات جسمك وصور تقدّمك';

  @override
  String get deleteAccountItemProfile =>
      'ملفك الشخصي وإعداداتك وأجهزة الإشعارات';

  @override
  String get deleteAccountIrreversible =>
      'لا يمكن التراجع عن ذلك. سيتم حذف حسابك وكل بياناته فورًا.';

  @override
  String get deleteAccountPasswordLabel => 'أدخل كلمة المرور للتأكيد';

  @override
  String get deleteAccountConfirmCheckbox =>
      'أفهم أن حسابي وكل بياناته سيُحذفون نهائيًا.';

  @override
  String get deleteAccountSubmit => 'حذف حسابي نهائيًا';

  @override
  String get deleteAccountSubmitting => 'جارٍ حذف حسابك…';

  @override
  String get deleteAccountWrongPassword =>
      'كلمة المرور غير صحيحة. حاول مرة أخرى.';

  @override
  String get deleteAccountTooManyAttempts =>
      'محاولات كثيرة. انتظر بضع دقائق ثم حاول مرة أخرى.';

  @override
  String get deleteAccountOffline => 'أنت غير متصل. اتصل بالإنترنت لحذف حسابك.';

  @override
  String get deleteAccountReauthRequired =>
      'سجّل الدخول مرة أخرى ثم أعد المحاولة.';

  @override
  String get deleteAccountUnsupported =>
      'حذف الحساب غير متاح لطريقة تسجيل الدخول هذه. تواصل مع الدعم.';

  @override
  String get deleteAccountFailed => 'تعذر إكمال حذف حسابك. حاول مرة أخرى.';

  @override
  String get accountDeletedNotice => 'تم حذف حسابك.';

  @override
  String get inactivityReminderTitle1 => 'إيه يا بطل، فينك من زمان! 👀❤️';

  @override
  String get inactivityReminderBody1 =>
      'بقالنا يومين من غير تمرين، بس عادي يا وحش. المهم منبعدش أكتر من كده، يلا نرجع واحدة واحدة 💪';

  @override
  String get inactivityReminderTitle2 => 'هو إحنا هنكسل ولا إيه؟ 😂🔥';

  @override
  String get inactivityReminderBody2 =>
      'عارف إن الدنيا بتاخدنا، بس متنساش إنك بتتعب عشان توصل لهدفك. حتى تمرينة خفيفة النهارده هتفرق ❤️';

  @override
  String get inactivityReminderTitle3 => 'بقولك إيه يا وحش 🦁';

  @override
  String get inactivityReminderBody3 =>
      'مش طالب منك تعمل المستحيل، كل اللي عايزه منك تبدأ. أول مجموعة بس، وبعدها هتلاقي نفسك كملت 💪🔥';

  @override
  String get inactivityReminderTitle4 => 'اسمع مني الكلمتين دول ❤️';

  @override
  String get inactivityReminderBody4 =>
      'مش كل يوم هتبقى عندك نفس الطاقة والحماس، وده طبيعي. المهم تفضل تحاول حتى لو بخطوات صغيرة 🤝';

  @override
  String get inactivityReminderTitle5 => 'إنت واحشني في التمرين يا نجم 😂💪';

  @override
  String get inactivityReminderBody5 =>
      'مش مهم غبت قد إيه، ولا فاتك كام تمرينة. اللي يفرق معايا إنك ترجع وتكمل اللي بدأته، براحتك ومن غير ضغط ❤️';

  @override
  String get inactivityReminderTitle6 => 'بص يا بطل، دي مني ليك ❤️';

  @override
  String get inactivityReminderBody6 =>
      'متستناش الحماس يرجع عشان تبدأ. ابدأ بحاجة بسيطة، والحماس هييجي مع الحركة. أنا مؤمن إنك تقدر تكمل 💪';

  @override
  String get deleteAccountIncomplete =>
      'لم يكتمل حذف سابق. أدخل كلمة المرور لإكماله.';

  @override
  String get deleteAccountIncompleteNotice =>
      'لم يكتمل حذف حسابك. إلى أن تُكمله من الإعدادات ← حذف الحساب، تُحفظ التعديلات الجديدة على هذا الهاتف فقط.';

  @override
  String get progressViewAll => 'عرض الكل';

  @override
  String get progressAllTimeCaption => 'منذ البداية';

  @override
  String progressSinceCaption(String date) {
    return 'منذ $date';
  }

  @override
  String progressMetricSemantics(String label, int value, String caption) {
    return '$label: $value، $caption';
  }

  @override
  String get progressLatestRecords => 'أحدث أرقامك القياسية';

  @override
  String get progressRecentWorkoutsSection => 'آخر التمارين';

  @override
  String get progressRangeDays => '7 أيام';

  @override
  String get progressRangeWeeks => '6 أسابيع';

  @override
  String get progressDailyChartSubtitle =>
      'عدد التمارين المكتملة يوميًا خلال آخر 7 أيام';

  @override
  String get progressWeeklyChartSubtitle =>
      'عدد التمارين المكتملة أسبوعيًا (من الاثنين إلى الأحد) خلال آخر 6 أسابيع';

  @override
  String get progressChartInfo =>
      'تُحسب التمرينة عند إنهائها مع تسجيل مجموعة واحدة على الأقل. التمارين الملغاة لا تُحسب.';

  @override
  String progressChartTotal(int count) {
    return 'الإجمالي: $count';
  }

  @override
  String progressChartBarSemantics(String period, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تمرين مكتمل',
      many: '$count تمرينًا مكتملًا',
      few: '$count تمارين مكتملة',
      two: 'تمرينان مكتملان',
      one: 'تمرين مكتمل واحد',
      zero: 'لا توجد تمارين مكتملة',
    );
    return '$period: $_temp0';
  }

  @override
  String progressWeekOf(String date) {
    return 'أسبوع $date';
  }

  @override
  String get progressTodayLabel => 'اليوم';

  @override
  String progressWorkoutCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تمرين',
      many: '$count تمرينًا',
      few: '$count تمارين',
      two: 'تمرينان',
      one: 'تمرين واحد',
      zero: 'لا تمارين',
    );
    return '$_temp0';
  }

  @override
  String progressExerciseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تمرين',
      many: '$count تمرينًا',
      few: '$count تمارين',
      two: 'تمرينان',
      one: 'تمرين واحد',
      zero: 'لا تمارين',
    );
    return '$_temp0';
  }

  @override
  String get progressRecordsEmpty =>
      'ستظهر أرقامك القياسية هنا بعد تسجيل مجموعات بأوزان.';

  @override
  String get progressRecordsSearchHint => 'ابحث باسم التمرين';

  @override
  String progressRecordsNoResults(String query) {
    return 'لا يوجد تمرين يطابق «$query».';
  }

  @override
  String get progressBestSetVolumeLabel =>
      'أفضل مجموعة واحدة (الوزن × التكرارات)';

  @override
  String progressRecordSetOn(String date) {
    return 'سُجّل في $date';
  }

  @override
  String get progressAllPrograms => 'كل البرامج';

  @override
  String get progressFilterByProgram => 'تصفية حسب البرنامج';

  @override
  String get progressHistoryNoResults =>
      'لا توجد تمارين مكتملة في هذا البرنامج بعد.';

  @override
  String get progressClearSearch => 'مسح البحث';

  @override
  String progressWeightTimesReps(String weight, int reps) {
    return '$weight كجم × $reps';
  }

  @override
  String progressSetVolumeFormula(String weight, int reps, String volume) {
    return '$weight كجم × $reps = $volume كجم';
  }

  @override
  String get syncReviewNeeded => 'يحتاج مراجعتك';

  @override
  String get syncReviewAction => 'مراجعة';

  @override
  String get syncEditedElsewhereTitle => 'تم التعديل من جهاز آخر';

  @override
  String get syncEditedElsewhereBody =>
      'عُدّل هذا اليوم هنا وعلى جهاز آخر. اختر النسخة التي تريد الاحتفاظ بها، وتبقى النسخة الأخرى محفوظة على هذا الهاتف.';

  @override
  String get syncDeletedElsewhereTitle => 'تم الحذف من جهاز آخر';

  @override
  String get syncDeletedElsewhereBody =>
      'حُذف هذا اليوم من جهاز آخر، لكنك عدّلته هنا. استعِده في كل الأجهزة، أو احذفه هنا أيضًا.';

  @override
  String get syncDeletedHereTitle => 'عُدّل من جهاز آخر بعد حذفه هنا';

  @override
  String get syncDeletedHereBody =>
      'حذفت هذا اليوم، لكنه عُدّل على جهاز آخر في الوقت نفسه. احذفه رغم ذلك، أو احتفظ به.';

  @override
  String get syncDiffersTitle => 'نسختان مختلفتان';

  @override
  String get syncDiffersBody =>
      'النسخة على هذا الهاتف تختلف عن المحفوظة في حسابك. اختر النسخة التي تريد الاحتفاظ بها، وتبقى الأخرى محفوظة على هذا الهاتف.';

  @override
  String get syncOlderBuildTitle => 'استبدلته نسخة أقدم من التطبيق';

  @override
  String get syncOlderBuildBody =>
      'استبدلت نسخة أقدم من التطبيق هذا اليوم في حسابك. اختر النسخة التي تريد الاحتفاظ بها.';

  @override
  String get syncKeepMine => 'استخدم نسخة هذا الهاتف';

  @override
  String get syncKeepCloud => 'استخدم النسخة الأخرى';

  @override
  String get syncRestoreDay => 'استعادة اليوم';

  @override
  String get syncDeleteHereToo => 'احذفه هنا أيضًا';

  @override
  String get syncDeleteAnyway => 'احذفه رغم ذلك';

  @override
  String get syncKeepDay => 'احتفظ باليوم';

  @override
  String get syncThisPhone => 'هذا الهاتف';

  @override
  String get syncOtherVersion => 'النسخة الأخرى';

  @override
  String get syncResolved =>
      'تم الحفظ. تبقى النسخة الأخرى محفوظة على هذا الهاتف.';

  @override
  String get syncLegacyTitle => 'وجدنا تمارين محفوظة سابقًا';

  @override
  String syncLegacyBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'حُفظ $count تمرين',
      many: 'حُفظ $count تمرينًا',
      few: 'حُفظت $count تمارين',
      two: 'حُفظ تمرينان',
      one: 'حُفظ تمرين واحد',
    );
    return '$_temp0 سابقًا لهذا اليوم. هل تريد استرجاعها؟';
  }

  @override
  String syncLegacySavedOn(String date) {
    return 'محفوظة في $date';
  }

  @override
  String get syncLegacyRestore => 'استرجاع';

  @override
  String get syncLegacyDismiss => 'عدم الاسترجاع';

  @override
  String get syncLegacyRestored => 'تم استرجاع التمارين.';

  @override
  String get syncEarlierVersionAvailable => 'توجد نسخة سابقة من هذا اليوم';

  @override
  String syncActivitiesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نشاط',
      many: '$count نشاطًا',
      few: '$count أنشطة',
      two: 'نشاطان',
      one: 'نشاط واحد',
      zero: 'لا أنشطة',
    );
    return '$_temp0';
  }

  @override
  String activityLimitReached(int limit) {
    return 'يمكن أن يحتوي يوم التمرين على $limit نشاطًا كحد أقصى.';
  }

  @override
  String syncLegacySplitNotice(int limit, int remaining, int newDays) {
    String _temp0 = intl.Intl.pluralLogic(
      newDays,
      locale: localeName,
      other: '$newDays يوم جديد',
      many: '$newDays يومًا جديدًا',
      few: '$newDays أيام جديدة',
      two: 'يومين جديدين',
      one: 'يوم جديد',
    );
    return 'يمكن أن يحتوي اليوم على $limit نشاطًا كحد أقصى. ستُستعاد أول $limit هنا، وتُنقل الـ$remaining الباقية إلى $_temp0 في نهاية هذا البرنامج.';
  }

  @override
  String syncNewDayLabel(String name) {
    return 'يوم جديد: $name';
  }

  @override
  String syncLegacyRestoredSplit(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'تم استرجاع التمارين في $days يوم.',
      many: 'تم استرجاع التمارين في $days يومًا.',
      few: 'تم استرجاع التمارين في $days أيام.',
      two: 'تم استرجاع التمارين في يومين.',
    );
    return '$_temp0';
  }

  @override
  String get syncTooManyTitle => 'أنشطة أكثر من المسموح بمزامنته';

  @override
  String syncTooManyBody(int count, int limit) {
    return 'يحتوي هذا اليوم على $count نشاطًا، أكثر من $limit المسموح بمزامنتها لليوم الواحد. حتى يتم تقسيمه تبقى تعديلاته على هذا الهاتف فقط.';
  }

  @override
  String get syncSplitDay => 'تقسيم اليوم';

  @override
  String get syncSplitConfirmTitle => 'تقسيم هذا اليوم؟';

  @override
  String syncSplitConfirmBody(int limit, int newDays) {
    String _temp0 = intl.Intl.pluralLogic(
      newDays,
      locale: localeName,
      other: '$newDays يوم جديد',
      many: '$newDays يومًا جديدًا',
      few: '$newDays أيام جديدة',
      two: 'يومين جديدين',
      one: 'يوم جديد',
    );
    return 'تنتقل الأنشطة التي بعد أول $limit بنفس الترتيب إلى $_temp0 في نهاية هذا البرنامج. لن يُحذف أي شيء.';
  }

  @override
  String syncSplitDone(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'تم تقسيم اليوم إلى $days يوم.',
      many: 'تم تقسيم اليوم إلى $days يومًا.',
      few: 'تم تقسيم اليوم إلى $days أيام.',
      two: 'تم تقسيم اليوم إلى يومين.',
    );
    return '$_temp0';
  }

  @override
  String get addActivityButton => 'إضافة نشاط';

  @override
  String get addActivityTitle => 'إضافة نشاط';

  @override
  String get addActivityStrengthTitle => 'تمرين مقاومة';

  @override
  String get addActivityStrengthBody => 'مجموعات وعدّات من مكتبة التمارين';

  @override
  String get addActivityCardioTitle => 'كارديو';

  @override
  String get addActivityCardioBody => 'المشاية والعجلة والجري وغيرها';

  @override
  String get addActivityLibraryTitle => 'مكتبتي';

  @override
  String get addActivityLibraryBody => 'تمارين وأنشطة أنشأتها بنفسك';

  @override
  String get cardioLibraryTitle => 'مكتبة الكارديو';

  @override
  String get cardioSearchHint => 'ابحث عن نشاط كارديو';

  @override
  String get cardioCategoryAll => 'الكل';

  @override
  String get cardioCategoryMachines => 'أجهزة ومعدات';

  @override
  String get cardioCategoryBodyweight => 'وزن الجسم';

  @override
  String get cardioCategoryOutdoor => 'في الخارج';

  @override
  String get cardioCategoryMine => 'الكارديو الخاص بي';

  @override
  String get cardioNoResults => 'لا يوجد نشاط كارديو يطابق بحثك.';

  @override
  String get cardioMineEmpty => 'تظهر هنا أنشطة الكارديو التي تنشئها.';

  @override
  String get cardioCreateCustom => 'إنشاء نشاط كارديو';

  @override
  String get cardioCustomNameLabel => 'اسم النشاط';

  @override
  String get cardioCreateAndAdd => 'إنشاء وإضافة';

  @override
  String get cardioAlreadyInDay => 'موجود في اليوم';

  @override
  String cardioAddAction(String name) {
    return 'إضافة $name';
  }

  @override
  String cardioAddedToDay(String name, String duration) {
    return 'تمت إضافة $name · $duration';
  }

  @override
  String cardioDurationMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes دقيقة',
      many: '$minutes دقيقة',
      few: '$minutes دقائق',
      two: 'دقيقتان',
      one: 'دقيقة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get cardioModeCountdown => 'عد تنازلي';

  @override
  String get cardioModeStopwatch => 'ساعة إيقاف';

  @override
  String get cardioModeIntervals => 'فترات';

  @override
  String cardioPlanSummary(String mode, String duration) {
    return '$mode · $duration';
  }

  @override
  String get cardioShadowBoxing => 'ملاكمة الظل';

  @override
  String get cardioHiking => 'المشي الجبلي';

  @override
  String get cardioSwimming => 'السباحة';

  @override
  String get cardioAirBikeAlsoKnown => 'تُعرف أيضًا باسم Assault Bike';

  @override
  String get activityTypeCardio => 'كارديو';

  @override
  String get myLibraryTitle => 'مكتبتي';

  @override
  String get myLibraryEmpty => 'تظهر هنا التمارين وأنشطة الكارديو التي تنشئها.';

  @override
  String get myLibraryStrengthSection => 'تمارين المقاومة';

  @override
  String get myLibraryCardioSection => 'كارديو';

  @override
  String get cardioSettingsTitle => 'إعدادات الكارديو';

  @override
  String get cardioTimerModeLabel => 'وضع المؤقت';

  @override
  String get cardioDurationLabel => 'المدة';

  @override
  String get cardioTargetToggle => 'تحديد مدة مستهدفة';

  @override
  String get cardioWorkLabel => 'عمل';

  @override
  String get cardioIntervalRestLabel => 'راحة';

  @override
  String get cardioRoundsLabel => 'الجولات';

  @override
  String get cardioWarmupLabel => 'إحماء';

  @override
  String get cardioCooldownLabel => 'تهدئة';

  @override
  String get cardioIntensityLabel => 'الشدة (اختيارية)';

  @override
  String get cardioIntensityLight => 'خفيفة';

  @override
  String get cardioIntensityModerate => 'متوسطة';

  @override
  String get cardioIntensityHigh => 'عالية';

  @override
  String get cardioIntensityLightHint =>
      'المجهود (RPE) من 2 إلى 4 من 10 · تستطيع التحدث بجمل كاملة.';

  @override
  String get cardioIntensityModerateHint =>
      'المجهود (RPE) من 5 إلى 6 من 10 · تستطيع الكلام لكن لا تستطيع الغناء.';

  @override
  String get cardioIntensityHighHint =>
      'المجهود (RPE) من 7 إلى 8 من 10 · كلمات قليلة فقط في كل مرة.';

  @override
  String get cardioDetailsLabel => 'تفاصيل (اختيارية)';

  @override
  String get cardioSpeedLabel => 'السرعة (كم/س)';

  @override
  String get cardioInclineLabel => 'الميل (%)';

  @override
  String get cardioResistanceLabel => 'مستوى المقاومة';

  @override
  String get cardioDistanceLabel => 'المسافة (كم)';

  @override
  String cardioValueRange(String min, String max) {
    return 'بين $min و$max';
  }

  @override
  String cardioPlannedTotal(String duration) {
    return 'المخطط: $duration';
  }

  @override
  String cardioSecondsValue(int seconds) {
    return '$seconds ث';
  }

  @override
  String get cardioNone => 'بدون';

  @override
  String get cardioSettingsSaved => 'تم حفظ إعدادات الكارديو.';

  @override
  String cardioDecrease(String label) {
    return 'تقليل $label';
  }

  @override
  String cardioIncrease(String label) {
    return 'زيادة $label';
  }

  @override
  String estimatedDuration(String duration) {
    return 'المدة التقديرية: $duration';
  }

  @override
  String estimatedDurationAtLeast(String duration) {
    return 'المدة التقديرية: $duration على الأقل';
  }

  @override
  String get estimatedDurationNote =>
      'تقدير من المجموعات والعدّات والراحة ومدة الكارديو المخططة، وليس الوقت الفعلي للتمرين.';

  @override
  String get undoAction => 'تراجع';

  @override
  String activityRemoved(String name) {
    return 'تمت إزالة $name';
  }

  @override
  String get cardioJustAddedHint =>
      'تمت إضافته إلى اليوم بهذه الإعدادات. احفظ لتغييرها، أو اضغط إلغاء للإبقاء عليها.';

  @override
  String get cardioTimerStart => 'ابدأ';

  @override
  String get cardioTimerPause => 'إيقاف مؤقت';

  @override
  String get cardioTimerResume => 'استئناف';

  @override
  String get cardioTimerFinish => 'إنهاء';

  @override
  String get cardioTimerSkip => 'تخطٍّ';

  @override
  String get cardioTimerOpen => 'فتح المؤقت';

  @override
  String get cardioTimerView => 'عرض';

  @override
  String get cardioTimerStartAgain => 'نفّذه رغم ذلك';

  @override
  String get cardioRemainingLabel => 'المتبقي';

  @override
  String get cardioElapsedLabel => 'المنقضي';

  @override
  String cardioPlannedValue(String duration) {
    return 'المخطط: $duration';
  }

  @override
  String cardioTargetValue(String duration) {
    return 'الهدف: $duration';
  }

  @override
  String get cardioNoTarget => 'بدون هدف: أنهِ النشاط عندما تنتهي';

  @override
  String cardioNextActivity(String name) {
    return 'التالي: $name';
  }

  @override
  String get cardioLastActivity => 'آخر نشاط في هذا التمرين';

  @override
  String get cardioStatusNotStarted => 'لم يبدأ';

  @override
  String cardioStatusRunning(String time) {
    return 'قيد التنفيذ · $time';
  }

  @override
  String cardioStatusPaused(String time) {
    return 'متوقف مؤقتًا · $time';
  }

  @override
  String cardioStatusCompleted(String time) {
    return 'تم · $time';
  }

  @override
  String cardioStatusEndedEarly(String time) {
    return 'انتهى مبكرًا · $time';
  }

  @override
  String get cardioStatusSkipped => 'تم تخطيه';

  @override
  String get intervalPhaseWarmup => 'إحماء';

  @override
  String get intervalPhaseWork => 'جهد';

  @override
  String get intervalPhaseRest => 'راحة';

  @override
  String get intervalPhaseCooldown => 'تهدئة';

  @override
  String intervalRoundOf(int current, int total) {
    return 'الجولة $current من $total';
  }

  @override
  String intervalNextPhase(String phase, String duration) {
    return 'التالي: $phase · $duration';
  }

  @override
  String get intervalLastPhase => 'المرحلة الأخيرة';

  @override
  String cardioSkipConfirmTitle(String name) {
    return 'تخطي $name؟';
  }

  @override
  String get cardioSkipConfirmBody =>
      'سيُسجَّل على أنه تم تخطيه، وليس على أنه مكتمل.';

  @override
  String get cardioFinishEarlyTitle => 'إنهاء الآن؟';

  @override
  String cardioFinishEarlyBody(String actual, String planned) {
    return 'تم $actual من $planned. سيُسجَّل على أنه انتهى مبكرًا.';
  }

  @override
  String get cardioSoundOn => 'الأصوات والاهتزاز مفعّلة';

  @override
  String get cardioSoundOff => 'الأصوات والاهتزاز متوقفة';

  @override
  String get cardioTargetReached => 'وصلت إلى الهدف. استمر أو أنهِ النشاط.';

  @override
  String cardioDoneMessage(String name, String time) {
    return 'اكتمل $name: $time';
  }

  @override
  String cardioSkippedMessage(String name) {
    return 'تم تخطي $name';
  }

  @override
  String get cardioBackgroundNote =>
      'يستمر المؤقت في العد إذا غادرت التطبيق أو قفلت الهاتف. الأصوات تعمل فقط أثناء فتح هذه الشاشة.';

  @override
  String get cardioTimerSaveError => 'تعذّر حفظ المؤقت. حاول مرة أخرى.';

  @override
  String get cardioTimerProgress => 'تقدّم المؤقت';

  @override
  String get finishWorkoutConfirmCardioBody =>
      'سيُحفظ الكارديو مع هذا التمرين في سجلك.';

  @override
  String get completionCardioTitle => 'الكارديو';

  @override
  String get cardioBackToWorkout => 'العودة إلى التمرين';
}
