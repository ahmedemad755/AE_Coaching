// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appBrandShort => 'AE';

  @override
  String get appBrandFull => 'AE COACHING';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get close => 'Close';

  @override
  String get retry => 'Retry';

  @override
  String get edit => 'Edit';

  @override
  String get languageToggleTooltip => 'Switch language';

  @override
  String get loginSubtitle => 'Login to Your Account';

  @override
  String get phoneNumberHint => 'Phone number';

  @override
  String get phoneNumberRequired => 'Enter your phone number';

  @override
  String get passwordHint => 'Password';

  @override
  String get passwordRequired => 'Enter your password';

  @override
  String get loginButton => 'LOGIN';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get registerNow => 'Register Now';

  @override
  String get loginSuccessMessage => 'Logged in successfully';

  @override
  String get genericSuccess => 'Success';

  @override
  String get createAccountTitle => 'Create Account';

  @override
  String get startJourneySubtitle => 'Start your coaching journey';

  @override
  String get fullNameHint => 'Full Name';

  @override
  String get fullNameRequired => 'Please enter your name';

  @override
  String get phoneNumberFieldHint => 'Phone Number';

  @override
  String get phoneNumberRequiredRegister => 'Please enter phone number';

  @override
  String get passwordTooShort => 'Password too short';

  @override
  String get createAccountButton => 'CREATE ACCOUNT';

  @override
  String get accountCreatedSuccess => 'Account created successfully';

  @override
  String get accountCreatedPendingLogin =>
      'Account created successfully. Please login.';

  @override
  String get verifyPhoneTitle => 'Verify Phone';

  @override
  String enterCodeSentTo(String phone) {
    return 'Enter the 6-digit code sent to $phone';
  }

  @override
  String get resendCodeTooltip => 'Resend Code';

  @override
  String get enterSixDigitCodeValidator => 'Enter the 6-digit code';

  @override
  String get resendButton => 'RESEND';

  @override
  String get verifyButton => 'VERIFY';

  @override
  String get accountVerifiedMessage => 'Account Verified! Please Login.';

  @override
  String get workoutTrackerSubtitle => 'Workout Tracker';

  @override
  String get logoutTooltip => 'Logout';

  @override
  String get logoutConfirmTitle => 'Logout';

  @override
  String get logoutConfirmBody =>
      'Are you sure you want to log out of your account?';

  @override
  String get measurementsTooltip => 'Measurements';

  @override
  String get progressAnalyticsTooltip => 'Progress Analytics';

  @override
  String get startFirstExercise => 'Start by adding your first exercise.';

  @override
  String get newExerciseButton => 'New Exercise';

  @override
  String get todaysVolumeLabel => 'Today\'s Volume: [kg]';

  @override
  String get historyLabel => 'History';

  @override
  String get analyticsLabel => 'Analytics';

  @override
  String get progressAnalyticsTitle => 'Progress Analytics';

  @override
  String get exerciseTrendsLabel => 'Exercise Trends';

  @override
  String get needMoreDataForProgress =>
      'Add at least two workout days to unlock progress analysis.';

  @override
  String exerciseNeedsMoreData(String name) {
    return '$name needs more data (2+ workouts)';
  }

  @override
  String lastPreviousVolume(String current, String previous) {
    return 'Last: $current kg | Previous: $previous kg';
  }

  @override
  String totalVolumeLabel(String date, String volume) {
    return '$date | Total Vol: $volume kg';
  }

  @override
  String get addNewExerciseTitle => 'Add New Exercise';

  @override
  String addSetToTitle(String name) {
    return 'Add Set to $name';
  }

  @override
  String editSetTitle(String name) {
    return 'Edit $name Set';
  }

  @override
  String get updateButton => 'Update';

  @override
  String get exerciseNameHint => 'Exercise Name';

  @override
  String get weightKgHint => 'Weight (kg)';

  @override
  String get repsHint => 'Reps';

  @override
  String get addAnotherSetButton => 'Add Another Set';

  @override
  String get setsColumnLabel => 'Sets';

  @override
  String get weightColumnLabel => 'Weight';

  @override
  String get repsColumnLabel => 'Reps';

  @override
  String get setLabel => 'Set';

  @override
  String get deleteExerciseTitle => 'Delete Exercise';

  @override
  String deleteExerciseBody(String name, int count, String unit) {
    return 'Are you sure you want to delete $name and its $count $unit?';
  }

  @override
  String get setUnitSingular => 'set';

  @override
  String get setUnitPlural => 'sets';

  @override
  String get todaysProgressLabel => 'TODAY\'S PROGRESS';

  @override
  String get totalTrainingVolumeLabel => 'TOTAL TRAINING VOLUME';

  @override
  String get trackedViaFooter => 'Tracked smoothly via AE Coaching App 🚀';

  @override
  String get shareProgressButton => 'Share Progress';

  @override
  String get sharingButton => 'Sharing...';

  @override
  String get bodyMeasurementsTitle => 'Body Measurements';

  @override
  String get addMeasurementButton => 'Add Measurement';

  @override
  String get somethingWrongLoadingMeasurements =>
      'Something went wrong loading your measurements.';

  @override
  String get lastCheckInLabel => 'Last Check-in';

  @override
  String get historyButton => 'History';

  @override
  String get analyticsButton => 'Analytics';

  @override
  String get noMeasurementsYetTitle => 'No body measurements yet.';

  @override
  String get addFirstCheckInSubtitle =>
      'Add your first measurement check-in to start tracking progress.';

  @override
  String get editMeasurementTitle => 'Edit Measurement';

  @override
  String get addMeasurementTitle => 'Add Measurement';

  @override
  String get allFieldsOptionalHint =>
      'All fields are optional — fill in whatever you measured today.';

  @override
  String get changeDateButton => 'Change Date';

  @override
  String get enterAtLeastOneMeasurement =>
      'Enter at least one measurement to save a check-in.';

  @override
  String get updateCheckInButton => 'Update Check-in';

  @override
  String get saveCheckInButton => 'Save Check-in';

  @override
  String get cmUnit => 'cm';

  @override
  String get measurementHistoryTitle => 'Measurement History';

  @override
  String get deleteCheckInTitle => 'Delete Check-in';

  @override
  String deleteCheckInBody(String date) {
    return 'Are you sure you want to delete the check-in from $date?';
  }

  @override
  String get unableToLoadHistory => 'Unable to load measurement history.';

  @override
  String get noMeasurementsHistoryEmpty =>
      'No body measurements yet.\n\nAdd your first measurement check-in to start tracking progress.';

  @override
  String get measurementAnalyticsTitle => 'Measurement Analytics';

  @override
  String get unableToLoadAnalytics => 'Unable to load measurement analytics.';

  @override
  String get notEnoughDataYet => 'Not enough data yet';

  @override
  String get sincePreviousCheckIn => 'Since Previous Check-in';

  @override
  String get overallProgress => 'Overall Progress';

  @override
  String get previousLabel => 'Previous';

  @override
  String get currentLabel => 'Current';

  @override
  String get firstLabel => 'First';

  @override
  String get latestLabel => 'Latest';

  @override
  String get noMeasurementsRecordedCheckIn =>
      'No measurements recorded for this check-in.';

  @override
  String get fieldChest => 'Chest';

  @override
  String get fieldWaist => 'Waist';

  @override
  String get fieldHips => 'Hips';

  @override
  String get fieldShoulders => 'Shoulders';

  @override
  String get fieldNeck => 'Neck';

  @override
  String get fieldRightArm => 'Right Arm';

  @override
  String get fieldLeftArm => 'Left Arm';

  @override
  String get fieldRightThigh => 'Right Thigh';

  @override
  String get fieldLeftThigh => 'Left Thigh';

  @override
  String get fieldRightCalf => 'Right Calf';

  @override
  String get fieldLeftCalf => 'Left Calf';

  @override
  String get progressPhotosTitle => 'Progress Photos';

  @override
  String get photosButton => 'Photos';

  @override
  String get addPhotoButton => 'Add Photo';

  @override
  String get choosePhotoSourceTitle => 'Add Progress Photo';

  @override
  String get cameraOption => 'Camera';

  @override
  String get galleryOption => 'Gallery';

  @override
  String get sinceLatestPhoto => 'Since Latest Photo';

  @override
  String get beforeLabel => 'Before';

  @override
  String get afterLabel => 'After';

  @override
  String get noPhotosYetTitle => 'No progress photos yet.';

  @override
  String get addFirstPhotoSubtitle =>
      'Add your first photo to start comparing your transformation.';

  @override
  String get photoHistoryTitle => 'Photo History';

  @override
  String get deletePhotoTitle => 'Delete Photo';

  @override
  String deletePhotoBody(String date) {
    return 'Are you sure you want to delete this photo from $date?';
  }

  @override
  String get addPhotoPromptTitle => 'Add a Progress Photo?';

  @override
  String get addPhotoPromptBody =>
      'Would you like to add a photo for today\'s check-in?';

  @override
  String get skip => 'Skip';

  @override
  String get unableToLoadPhotos => 'Unable to load progress photos.';
}
