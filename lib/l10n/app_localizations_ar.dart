// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

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
  String get loginSubtitle => 'تسجيل الدخول لحسابك';

  @override
  String get phoneNumberHint => 'رقم الهاتف';

  @override
  String get phoneNumberRequired => 'من فضلك أدخل رقم هاتفك';

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
  String get phoneNumberFieldHint => 'رقم الهاتف';

  @override
  String get phoneNumberRequiredRegister => 'من فضلك أدخل رقم الهاتف';

  @override
  String get passwordTooShort => 'كلمة المرور قصيرة جدًا';

  @override
  String get createAccountButton => 'إنشاء الحساب';

  @override
  String get accountCreatedSuccess => 'تم إنشاء الحساب بنجاح';

  @override
  String get accountCreatedPendingLogin =>
      'تم إنشاء الحساب بنجاح. من فضلك سجّل الدخول.';

  @override
  String get verifyPhoneTitle => 'تفعيل رقم الهاتف';

  @override
  String enterCodeSentTo(String phone) {
    return 'أدخل الكود المكوّن من 6 أرقام اللي اتبعت لـ $phone';
  }

  @override
  String get resendCodeTooltip => 'إعادة إرسال الكود';

  @override
  String get enterSixDigitCodeValidator => 'أدخل الكود المكوّن من 6 أرقام';

  @override
  String get resendButton => 'إعادة الإرسال';

  @override
  String get verifyButton => 'تأكيد';

  @override
  String get accountVerifiedMessage => 'تم تفعيل الحساب! من فضلك سجّل الدخول.';

  @override
  String get completeRegistrationSetPasswordTitle => 'اختر كلمة مرور';

  @override
  String completeRegistrationSetPasswordSubtitle(String phone) {
    return 'تم تفعيل رقم هاتفك $phone. اختر كلمة مرور لتأمين حسابك.';
  }

  @override
  String get completeRegistrationFinishProfileTitle => 'أكمل ملفك الشخصي';

  @override
  String get completeRegistrationFinishProfileSubtitle =>
      'محتاجين اسمك بس عشان نخلّص إعداد حسابك.';

  @override
  String get completeRegistrationCancelAndSignOut => 'دي مش أنا — ابدأ من جديد';

  @override
  String get sessionCheckingMessage => 'جاري التحقق من حسابك...';

  @override
  String get verifyPhoneMigrationTitle => 'تفعيل رقم هاتفك';

  @override
  String verifyPhoneMigrationSubtitle(String phone) {
    return 'لأمان حسابك، أدخل الكود اللي اتبعت لـ $phone.';
  }

  @override
  String get phoneVerifiedSuccessMessage => 'تم تفعيل رقم الهاتف بنجاح';

  @override
  String get forgotPasswordTitle => 'إعادة تعيين كلمة المرور';

  @override
  String get forgotPasswordSubtitle => 'أدخل رقم هاتفك وهنبعتلك كود تفعيل.';

  @override
  String get sendCodeButton => 'إرسال الكود';

  @override
  String get resetPasswordTitle => 'أدخل كلمة مرور جديدة';

  @override
  String resetPasswordSubtitle(String phone) {
    return 'أدخل الكود اللي اتبعت لـ $phone واختر كلمة مرور جديدة.';
  }

  @override
  String get confirmPasswordHint => 'تأكيد كلمة المرور';

  @override
  String get confirmPasswordRequired => 'من فضلك أكّد كلمة المرور';

  @override
  String get passwordsDoNotMatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get resetPasswordButton => 'تغيير كلمة المرور';

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
  String get newExerciseButton => 'تمرين جديد';

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
}
