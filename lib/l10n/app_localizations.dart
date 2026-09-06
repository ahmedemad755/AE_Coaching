import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appBrandShort.
  ///
  /// In en, this message translates to:
  /// **'AE'**
  String get appBrandShort;

  /// No description provided for @appBrandFull.
  ///
  /// In en, this message translates to:
  /// **'AE COACHING'**
  String get appBrandFull;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @languageToggleTooltip.
  ///
  /// In en, this message translates to:
  /// **'Switch language'**
  String get languageToggleTooltip;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Login to Your Account'**
  String get loginSubtitle;

  /// No description provided for @phoneNumberHint.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumberHint;

  /// No description provided for @phoneNumberRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get phoneNumberRequired;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordHint;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get passwordRequired;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'LOGIN'**
  String get loginButton;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @registerNow.
  ///
  /// In en, this message translates to:
  /// **'Register Now'**
  String get registerNow;

  /// No description provided for @loginSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Logged in successfully'**
  String get loginSuccessMessage;

  /// No description provided for @genericSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get genericSuccess;

  /// No description provided for @createAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccountTitle;

  /// No description provided for @startJourneySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start your coaching journey'**
  String get startJourneySubtitle;

  /// No description provided for @fullNameHint.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullNameHint;

  /// No description provided for @fullNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get fullNameRequired;

  /// No description provided for @phoneNumberFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumberFieldHint;

  /// No description provided for @phoneNumberRequiredRegister.
  ///
  /// In en, this message translates to:
  /// **'Please enter phone number'**
  String get phoneNumberRequiredRegister;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password too short'**
  String get passwordTooShort;

  /// No description provided for @createAccountButton.
  ///
  /// In en, this message translates to:
  /// **'CREATE ACCOUNT'**
  String get createAccountButton;

  /// No description provided for @accountCreatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Account created successfully'**
  String get accountCreatedSuccess;

  /// No description provided for @accountCreatedPendingLogin.
  ///
  /// In en, this message translates to:
  /// **'Account created successfully. Please login.'**
  String get accountCreatedPendingLogin;

  /// No description provided for @verifyPhoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify Phone'**
  String get verifyPhoneTitle;

  /// No description provided for @enterCodeSentTo.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code sent to {phone}'**
  String enterCodeSentTo(String phone);

  /// No description provided for @resendCodeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Resend Code'**
  String get resendCodeTooltip;

  /// No description provided for @enterSixDigitCodeValidator.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code'**
  String get enterSixDigitCodeValidator;

  /// No description provided for @resendButton.
  ///
  /// In en, this message translates to:
  /// **'RESEND'**
  String get resendButton;

  /// No description provided for @verifyButton.
  ///
  /// In en, this message translates to:
  /// **'VERIFY'**
  String get verifyButton;

  /// No description provided for @accountVerifiedMessage.
  ///
  /// In en, this message translates to:
  /// **'Account Verified! Please Login.'**
  String get accountVerifiedMessage;

  /// No description provided for @workoutTrackerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Workout Tracker'**
  String get workoutTrackerSubtitle;

  /// No description provided for @logoutTooltip.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logoutTooltip;

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out of your account?'**
  String get logoutConfirmBody;

  /// No description provided for @measurementsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Measurements'**
  String get measurementsTooltip;

  /// No description provided for @progressAnalyticsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Progress Analytics'**
  String get progressAnalyticsTooltip;

  /// No description provided for @startFirstExercise.
  ///
  /// In en, this message translates to:
  /// **'Start by adding your first exercise.'**
  String get startFirstExercise;

  /// No description provided for @newExerciseButton.
  ///
  /// In en, this message translates to:
  /// **'New Exercise'**
  String get newExerciseButton;

  /// No description provided for @todaysVolumeLabel.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Volume: [kg]'**
  String get todaysVolumeLabel;

  /// No description provided for @historyLabel.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyLabel;

  /// No description provided for @analyticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analyticsLabel;

  /// No description provided for @progressAnalyticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Progress Analytics'**
  String get progressAnalyticsTitle;

  /// No description provided for @exerciseTrendsLabel.
  ///
  /// In en, this message translates to:
  /// **'Exercise Trends'**
  String get exerciseTrendsLabel;

  /// No description provided for @needMoreDataForProgress.
  ///
  /// In en, this message translates to:
  /// **'Add at least two workout days to unlock progress analysis.'**
  String get needMoreDataForProgress;

  /// No description provided for @exerciseNeedsMoreData.
  ///
  /// In en, this message translates to:
  /// **'{name} needs more data (2+ workouts)'**
  String exerciseNeedsMoreData(String name);

  /// No description provided for @lastPreviousVolume.
  ///
  /// In en, this message translates to:
  /// **'Last: {current} kg | Previous: {previous} kg'**
  String lastPreviousVolume(String current, String previous);

  /// No description provided for @totalVolumeLabel.
  ///
  /// In en, this message translates to:
  /// **'{date} | Total Vol: {volume} kg'**
  String totalVolumeLabel(String date, String volume);

  /// No description provided for @addNewExerciseTitle.
  ///
  /// In en, this message translates to:
  /// **'Add New Exercise'**
  String get addNewExerciseTitle;

  /// No description provided for @addSetToTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Set to {name}'**
  String addSetToTitle(String name);

  /// No description provided for @editSetTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit {name} Set'**
  String editSetTitle(String name);

  /// No description provided for @updateButton.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateButton;

  /// No description provided for @exerciseNameHint.
  ///
  /// In en, this message translates to:
  /// **'Exercise Name'**
  String get exerciseNameHint;

  /// No description provided for @weightKgHint.
  ///
  /// In en, this message translates to:
  /// **'Weight (kg)'**
  String get weightKgHint;

  /// No description provided for @repsHint.
  ///
  /// In en, this message translates to:
  /// **'Reps'**
  String get repsHint;

  /// No description provided for @addAnotherSetButton.
  ///
  /// In en, this message translates to:
  /// **'Add Another Set'**
  String get addAnotherSetButton;

  /// No description provided for @setsColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Sets'**
  String get setsColumnLabel;

  /// No description provided for @weightColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weightColumnLabel;

  /// No description provided for @repsColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Reps'**
  String get repsColumnLabel;

  /// No description provided for @setLabel.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get setLabel;

  /// No description provided for @deleteExerciseTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Exercise'**
  String get deleteExerciseTitle;

  /// No description provided for @deleteExerciseBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {name} and its {count} {unit}?'**
  String deleteExerciseBody(String name, int count, String unit);

  /// No description provided for @setUnitSingular.
  ///
  /// In en, this message translates to:
  /// **'set'**
  String get setUnitSingular;

  /// No description provided for @setUnitPlural.
  ///
  /// In en, this message translates to:
  /// **'sets'**
  String get setUnitPlural;

  /// No description provided for @todaysProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'TODAY\'S PROGRESS'**
  String get todaysProgressLabel;

  /// No description provided for @totalTrainingVolumeLabel.
  ///
  /// In en, this message translates to:
  /// **'TOTAL TRAINING VOLUME'**
  String get totalTrainingVolumeLabel;

  /// No description provided for @trackedViaFooter.
  ///
  /// In en, this message translates to:
  /// **'Tracked smoothly via AE Coaching App 🚀'**
  String get trackedViaFooter;

  /// No description provided for @shareProgressButton.
  ///
  /// In en, this message translates to:
  /// **'Share Progress'**
  String get shareProgressButton;

  /// No description provided for @sharingButton.
  ///
  /// In en, this message translates to:
  /// **'Sharing...'**
  String get sharingButton;

  /// No description provided for @bodyMeasurementsTitle.
  ///
  /// In en, this message translates to:
  /// **'Body Measurements'**
  String get bodyMeasurementsTitle;

  /// No description provided for @addMeasurementButton.
  ///
  /// In en, this message translates to:
  /// **'Add Measurement'**
  String get addMeasurementButton;

  /// No description provided for @somethingWrongLoadingMeasurements.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong loading your measurements.'**
  String get somethingWrongLoadingMeasurements;

  /// No description provided for @lastCheckInLabel.
  ///
  /// In en, this message translates to:
  /// **'Last Check-in'**
  String get lastCheckInLabel;

  /// No description provided for @historyButton.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyButton;

  /// No description provided for @analyticsButton.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analyticsButton;

  /// No description provided for @noMeasurementsYetTitle.
  ///
  /// In en, this message translates to:
  /// **'No body measurements yet.'**
  String get noMeasurementsYetTitle;

  /// No description provided for @addFirstCheckInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add your first measurement check-in to start tracking progress.'**
  String get addFirstCheckInSubtitle;

  /// No description provided for @editMeasurementTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Measurement'**
  String get editMeasurementTitle;

  /// No description provided for @addMeasurementTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Measurement'**
  String get addMeasurementTitle;

  /// No description provided for @allFieldsOptionalHint.
  ///
  /// In en, this message translates to:
  /// **'All fields are optional — fill in whatever you measured today.'**
  String get allFieldsOptionalHint;

  /// No description provided for @changeDateButton.
  ///
  /// In en, this message translates to:
  /// **'Change Date'**
  String get changeDateButton;

  /// No description provided for @enterAtLeastOneMeasurement.
  ///
  /// In en, this message translates to:
  /// **'Enter at least one measurement to save a check-in.'**
  String get enterAtLeastOneMeasurement;

  /// No description provided for @updateCheckInButton.
  ///
  /// In en, this message translates to:
  /// **'Update Check-in'**
  String get updateCheckInButton;

  /// No description provided for @saveCheckInButton.
  ///
  /// In en, this message translates to:
  /// **'Save Check-in'**
  String get saveCheckInButton;

  /// No description provided for @cmUnit.
  ///
  /// In en, this message translates to:
  /// **'cm'**
  String get cmUnit;

  /// No description provided for @measurementHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Measurement History'**
  String get measurementHistoryTitle;

  /// No description provided for @deleteCheckInTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Check-in'**
  String get deleteCheckInTitle;

  /// No description provided for @deleteCheckInBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete the check-in from {date}?'**
  String deleteCheckInBody(String date);

  /// No description provided for @unableToLoadHistory.
  ///
  /// In en, this message translates to:
  /// **'Unable to load measurement history.'**
  String get unableToLoadHistory;

  /// No description provided for @noMeasurementsHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No body measurements yet.\n\nAdd your first measurement check-in to start tracking progress.'**
  String get noMeasurementsHistoryEmpty;

  /// No description provided for @measurementAnalyticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Measurement Analytics'**
  String get measurementAnalyticsTitle;

  /// No description provided for @unableToLoadAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Unable to load measurement analytics.'**
  String get unableToLoadAnalytics;

  /// No description provided for @notEnoughDataYet.
  ///
  /// In en, this message translates to:
  /// **'Not enough data yet'**
  String get notEnoughDataYet;

  /// No description provided for @sincePreviousCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Since Previous Check-in'**
  String get sincePreviousCheckIn;

  /// No description provided for @overallProgress.
  ///
  /// In en, this message translates to:
  /// **'Overall Progress'**
  String get overallProgress;

  /// No description provided for @previousLabel.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previousLabel;

  /// No description provided for @currentLabel.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get currentLabel;

  /// No description provided for @firstLabel.
  ///
  /// In en, this message translates to:
  /// **'First'**
  String get firstLabel;

  /// No description provided for @latestLabel.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get latestLabel;

  /// No description provided for @noMeasurementsRecordedCheckIn.
  ///
  /// In en, this message translates to:
  /// **'No measurements recorded for this check-in.'**
  String get noMeasurementsRecordedCheckIn;

  /// No description provided for @fieldChest.
  ///
  /// In en, this message translates to:
  /// **'Chest'**
  String get fieldChest;

  /// No description provided for @fieldWaist.
  ///
  /// In en, this message translates to:
  /// **'Waist'**
  String get fieldWaist;

  /// No description provided for @fieldHips.
  ///
  /// In en, this message translates to:
  /// **'Hips'**
  String get fieldHips;

  /// No description provided for @fieldShoulders.
  ///
  /// In en, this message translates to:
  /// **'Shoulders'**
  String get fieldShoulders;

  /// No description provided for @fieldNeck.
  ///
  /// In en, this message translates to:
  /// **'Neck'**
  String get fieldNeck;

  /// No description provided for @fieldRightArm.
  ///
  /// In en, this message translates to:
  /// **'Right Arm'**
  String get fieldRightArm;

  /// No description provided for @fieldLeftArm.
  ///
  /// In en, this message translates to:
  /// **'Left Arm'**
  String get fieldLeftArm;

  /// No description provided for @fieldRightThigh.
  ///
  /// In en, this message translates to:
  /// **'Right Thigh'**
  String get fieldRightThigh;

  /// No description provided for @fieldLeftThigh.
  ///
  /// In en, this message translates to:
  /// **'Left Thigh'**
  String get fieldLeftThigh;

  /// No description provided for @fieldRightCalf.
  ///
  /// In en, this message translates to:
  /// **'Right Calf'**
  String get fieldRightCalf;

  /// No description provided for @fieldLeftCalf.
  ///
  /// In en, this message translates to:
  /// **'Left Calf'**
  String get fieldLeftCalf;

  /// No description provided for @progressPhotosTitle.
  ///
  /// In en, this message translates to:
  /// **'Progress Photos'**
  String get progressPhotosTitle;

  /// No description provided for @photosButton.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get photosButton;

  /// No description provided for @addPhotoButton.
  ///
  /// In en, this message translates to:
  /// **'Add Photo'**
  String get addPhotoButton;

  /// No description provided for @choosePhotoSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Progress Photo'**
  String get choosePhotoSourceTitle;

  /// No description provided for @cameraOption.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get cameraOption;

  /// No description provided for @galleryOption.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get galleryOption;

  /// No description provided for @sinceLatestPhoto.
  ///
  /// In en, this message translates to:
  /// **'Since Latest Photo'**
  String get sinceLatestPhoto;

  /// No description provided for @beforeLabel.
  ///
  /// In en, this message translates to:
  /// **'Before'**
  String get beforeLabel;

  /// No description provided for @afterLabel.
  ///
  /// In en, this message translates to:
  /// **'After'**
  String get afterLabel;

  /// No description provided for @noPhotosYetTitle.
  ///
  /// In en, this message translates to:
  /// **'No progress photos yet.'**
  String get noPhotosYetTitle;

  /// No description provided for @addFirstPhotoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add your first photo to start comparing your transformation.'**
  String get addFirstPhotoSubtitle;

  /// No description provided for @photoHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Photo History'**
  String get photoHistoryTitle;

  /// No description provided for @deletePhotoTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Photo'**
  String get deletePhotoTitle;

  /// No description provided for @deletePhotoBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this photo from {date}?'**
  String deletePhotoBody(String date);

  /// No description provided for @addPhotoPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a Progress Photo?'**
  String get addPhotoPromptTitle;

  /// No description provided for @addPhotoPromptBody.
  ///
  /// In en, this message translates to:
  /// **'Would you like to add a photo for today\'s check-in?'**
  String get addPhotoPromptBody;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @unableToLoadPhotos.
  ///
  /// In en, this message translates to:
  /// **'Unable to load progress photos.'**
  String get unableToLoadPhotos;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
