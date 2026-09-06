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
}
