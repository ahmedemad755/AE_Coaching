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

  /// No description provided for @completeRegistrationSetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Set a password'**
  String get completeRegistrationSetPasswordTitle;

  /// No description provided for @completeRegistrationSetPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your phone number {phone} is verified. Choose a password to secure your account.'**
  String completeRegistrationSetPasswordSubtitle(String phone);

  /// No description provided for @completeRegistrationFinishProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Finish your profile'**
  String get completeRegistrationFinishProfileTitle;

  /// No description provided for @completeRegistrationFinishProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Just need your name to finish setting up your account.'**
  String get completeRegistrationFinishProfileSubtitle;

  /// No description provided for @completeRegistrationCancelAndSignOut.
  ///
  /// In en, this message translates to:
  /// **'This isn\'t me — start over'**
  String get completeRegistrationCancelAndSignOut;

  /// No description provided for @sessionCheckingMessage.
  ///
  /// In en, this message translates to:
  /// **'Checking your account...'**
  String get sessionCheckingMessage;

  /// No description provided for @verifyPhoneMigrationTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your phone'**
  String get verifyPhoneMigrationTitle;

  /// No description provided for @verifyPhoneMigrationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'For your account\'s security, confirm the code sent to {phone}.'**
  String verifyPhoneMigrationSubtitle(String phone);

  /// No description provided for @phoneVerifiedSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Phone verified successfully'**
  String get phoneVerifiedSuccessMessage;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number and we\'ll send you a verification code.'**
  String get forgotPasswordSubtitle;

  /// No description provided for @sendCodeButton.
  ///
  /// In en, this message translates to:
  /// **'SEND CODE'**
  String get sendCodeButton;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter new password'**
  String get resetPasswordTitle;

  /// No description provided for @resetPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the code sent to {phone} and choose a new password.'**
  String resetPasswordSubtitle(String phone);

  /// No description provided for @confirmPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPasswordHint;

  /// No description provided for @confirmPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get confirmPasswordRequired;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @resetPasswordButton.
  ///
  /// In en, this message translates to:
  /// **'RESET PASSWORD'**
  String get resetPasswordButton;

  /// No description provided for @passwordChangedSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Password changed successfully'**
  String get passwordChangedSuccessMessage;

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

  /// No description provided for @myProgramsTitle.
  ///
  /// In en, this message translates to:
  /// **'My Programs'**
  String get myProgramsTitle;

  /// No description provided for @activeProgramLabel.
  ///
  /// In en, this message translates to:
  /// **'Active Program'**
  String get activeProgramLabel;

  /// No description provided for @previousProgramsLabel.
  ///
  /// In en, this message translates to:
  /// **'Previous Programs'**
  String get previousProgramsLabel;

  /// No description provided for @createProgramButton.
  ///
  /// In en, this message translates to:
  /// **'Create Program'**
  String get createProgramButton;

  /// No description provided for @createProgramTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Program'**
  String get createProgramTitle;

  /// No description provided for @programNameHint.
  ///
  /// In en, this message translates to:
  /// **'Program Name'**
  String get programNameHint;

  /// No description provided for @descriptionOptionalHint.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get descriptionOptionalHint;

  /// No description provided for @createButton.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get createButton;

  /// No description provided for @createAndMakeActiveButton.
  ///
  /// In en, this message translates to:
  /// **'Create & Make Active'**
  String get createAndMakeActiveButton;

  /// No description provided for @makeActiveButton.
  ///
  /// In en, this message translates to:
  /// **'Make Active'**
  String get makeActiveButton;

  /// No description provided for @renameButton.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get renameButton;

  /// No description provided for @renameProgramTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename Program'**
  String get renameProgramTitle;

  /// No description provided for @archiveButton.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archiveButton;

  /// No description provided for @openButton.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openButton;

  /// No description provided for @noProgramsYetTitle.
  ///
  /// In en, this message translates to:
  /// **'No programs yet.'**
  String get noProgramsYetTitle;

  /// No description provided for @noProgramsYetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create your first program to start organizing your training.'**
  String get noProgramsYetSubtitle;

  /// No description provided for @makeActiveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Make Active?'**
  String get makeActiveConfirmTitle;

  /// No description provided for @makeActiveConfirmBodyWithCurrent.
  ///
  /// In en, this message translates to:
  /// **'Make \"{name}\" your active program? Your current program will remain saved as a previous program.'**
  String makeActiveConfirmBodyWithCurrent(String name);

  /// No description provided for @makeActiveConfirmBodyNoCurrent.
  ///
  /// In en, this message translates to:
  /// **'Make \"{name}\" your active program?'**
  String makeActiveConfirmBodyNoCurrent(String name);

  /// No description provided for @archiveActiveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive Program?'**
  String get archiveActiveConfirmTitle;

  /// No description provided for @archiveActiveConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Archive \"{name}\"? It will move to Previous Programs — your workout history stays intact.'**
  String archiveActiveConfirmBody(String name);

  /// No description provided for @enterProgramNameValidation.
  ///
  /// In en, this message translates to:
  /// **'Enter a program name.'**
  String get enterProgramNameValidation;

  /// No description provided for @unableToLoadProgramsError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load your programs.'**
  String get unableToLoadProgramsError;

  /// No description provided for @workoutDaysPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Workout Days will be added in the next phase.'**
  String get workoutDaysPlaceholder;

  /// No description provided for @startedLabel.
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get startedLabel;

  /// No description provided for @endedLabel.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get endedLabel;

  /// No description provided for @workoutProgramsTooltip.
  ///
  /// In en, this message translates to:
  /// **'My Programs'**
  String get workoutProgramsTooltip;

  /// No description provided for @workoutDaysTitle.
  ///
  /// In en, this message translates to:
  /// **'Workout Days'**
  String get workoutDaysTitle;

  /// No description provided for @addWorkoutDayButton.
  ///
  /// In en, this message translates to:
  /// **'Add Workout Day'**
  String get addWorkoutDayButton;

  /// No description provided for @createWorkoutDayTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Workout Day'**
  String get createWorkoutDayTitle;

  /// No description provided for @renameWorkoutDayTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename Workout Day'**
  String get renameWorkoutDayTitle;

  /// No description provided for @workoutDayNameHint.
  ///
  /// In en, this message translates to:
  /// **'Workout Day Name'**
  String get workoutDayNameHint;

  /// No description provided for @noWorkoutDaysYetTitle.
  ///
  /// In en, this message translates to:
  /// **'No workout days yet.'**
  String get noWorkoutDaysYetTitle;

  /// No description provided for @noWorkoutDaysYetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add a workout day like \"Push 1\" to start building this program.'**
  String get noWorkoutDaysYetSubtitle;

  /// No description provided for @archiveWorkoutDayConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive Workout Day?'**
  String get archiveWorkoutDayConfirmTitle;

  /// No description provided for @archiveWorkoutDayConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Archive \"{name}\"? It will be hidden from this list, but any workout history stays intact.'**
  String archiveWorkoutDayConfirmBody(String name);

  /// No description provided for @enterWorkoutDayNameValidation.
  ///
  /// In en, this message translates to:
  /// **'Enter a workout day name.'**
  String get enterWorkoutDayNameValidation;

  /// No description provided for @unableToLoadWorkoutDaysError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load workout days.'**
  String get unableToLoadWorkoutDaysError;

  /// No description provided for @startWorkoutButton.
  ///
  /// In en, this message translates to:
  /// **'Start Workout'**
  String get startWorkoutButton;

  /// No description provided for @moveUpTooltip.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get moveUpTooltip;

  /// No description provided for @moveDownTooltip.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get moveDownTooltip;

  /// No description provided for @startWorkoutComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Starting a workout is coming in the next phase.'**
  String get startWorkoutComingSoon;

  /// No description provided for @resumeWorkoutBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Workout in progress'**
  String get resumeWorkoutBannerTitle;

  /// No description provided for @resumeWorkoutBannerBody.
  ///
  /// In en, this message translates to:
  /// **'{name} — started {elapsed} ago'**
  String resumeWorkoutBannerBody(String name, String elapsed);

  /// No description provided for @resumeWorkoutButton.
  ///
  /// In en, this message translates to:
  /// **'Resume Workout'**
  String get resumeWorkoutButton;

  /// No description provided for @workoutInProgressConflictTitle.
  ///
  /// In en, this message translates to:
  /// **'Workout Already In Progress'**
  String get workoutInProgressConflictTitle;

  /// No description provided for @workoutInProgressConflictBody.
  ///
  /// In en, this message translates to:
  /// **'You already have \"{name}\" in progress. Finish or cancel it before starting a new workout.'**
  String workoutInProgressConflictBody(String name);

  /// No description provided for @cancelWorkoutButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel Workout'**
  String get cancelWorkoutButton;

  /// No description provided for @cancelWorkoutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this workout?'**
  String get cancelWorkoutConfirmTitle;

  /// No description provided for @cancelWorkoutConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This workout session will be marked cancelled and won\'t count toward your history. This can\'t be undone.'**
  String get cancelWorkoutConfirmBody;

  /// No description provided for @finishWorkoutButton.
  ///
  /// In en, this message translates to:
  /// **'Finish Workout'**
  String get finishWorkoutButton;

  /// No description provided for @finishWorkoutComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Finishing a workout is coming in the next phase.'**
  String get finishWorkoutComingSoon;

  /// No description provided for @elapsedTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Elapsed Time'**
  String get elapsedTimeLabel;

  /// No description provided for @unableToStartWorkoutError.
  ///
  /// In en, this message translates to:
  /// **'Unable to start the workout.'**
  String get unableToStartWorkoutError;

  /// No description provided for @sessionExercisesTitle.
  ///
  /// In en, this message translates to:
  /// **'Exercises'**
  String get sessionExercisesTitle;

  /// No description provided for @noExercisesLoggedYetBody.
  ///
  /// In en, this message translates to:
  /// **'No exercises logged yet. Tap \"New Exercise\" to add your first set.'**
  String get noExercisesLoggedYetBody;

  /// No description provided for @suggestedFromLastTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Suggested from last time'**
  String get suggestedFromLastTimeLabel;

  /// No description provided for @logFirstSetButton.
  ///
  /// In en, this message translates to:
  /// **'Log Set'**
  String get logFirstSetButton;

  /// No description provided for @addSetTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add another set'**
  String get addSetTooltip;

  /// No description provided for @deleteSetTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete set'**
  String get deleteSetTooltip;

  /// No description provided for @unableToLogSetError.
  ///
  /// In en, this message translates to:
  /// **'Unable to log this set.'**
  String get unableToLogSetError;

  /// No description provided for @exerciseNameRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Please enter an exercise name.'**
  String get exerciseNameRequiredError;

  /// No description provided for @lastTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Last time'**
  String get lastTimeLabel;

  /// No description provided for @finishWorkoutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Finish this workout?'**
  String get finishWorkoutConfirmTitle;

  /// No description provided for @finishWorkoutConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Total volume logged: {volume} kg. This will mark the session complete and save it to your history.'**
  String finishWorkoutConfirmBody(String volume);

  /// No description provided for @workoutFinishedBody.
  ///
  /// In en, this message translates to:
  /// **'Workout completed! Total volume: {volume} kg.'**
  String workoutFinishedBody(String volume);

  /// No description provided for @unableToFinishWorkoutError.
  ///
  /// In en, this message translates to:
  /// **'Unable to finish the workout.'**
  String get unableToFinishWorkoutError;

  /// No description provided for @workoutSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Workout Summary'**
  String get workoutSummaryTitle;

  /// No description provided for @sessionTotalVolumeLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Volume'**
  String get sessionTotalVolumeLabel;

  /// No description provided for @sinceLastTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Since Last Time'**
  String get sinceLastTimeLabel;

  /// No description provided for @noPreviousSessionBody.
  ///
  /// In en, this message translates to:
  /// **'No previous session for this workout day yet — next time you\'ll see how you compare.'**
  String get noPreviousSessionBody;

  /// No description provided for @newPersonalRecordsLabel.
  ///
  /// In en, this message translates to:
  /// **'New Personal Records'**
  String get newPersonalRecordsLabel;

  /// No description provided for @firstTimePrBody.
  ///
  /// In en, this message translates to:
  /// **'First time logging {exercise}!'**
  String firstTimePrBody(String exercise);

  /// No description provided for @heaviestWeightPrBody.
  ///
  /// In en, this message translates to:
  /// **'{exercise}: heaviest weight ever — {weight} kg (was {previous} kg)'**
  String heaviestWeightPrBody(String exercise, String weight, String previous);

  /// No description provided for @highestSetVolumePrBody.
  ///
  /// In en, this message translates to:
  /// **'{exercise}: best single set ever — {weight} kg × {reps}'**
  String highestSetVolumePrBody(String exercise, String weight, int reps);

  /// No description provided for @exerciseImprovedLabel.
  ///
  /// In en, this message translates to:
  /// **'Improved'**
  String get exerciseImprovedLabel;

  /// No description provided for @exerciseMaintainedLabel.
  ///
  /// In en, this message translates to:
  /// **'Maintained'**
  String get exerciseMaintainedLabel;

  /// No description provided for @exerciseDeclinedLabel.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get exerciseDeclinedLabel;

  /// No description provided for @exerciseNewLabel.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get exerciseNewLabel;

  /// No description provided for @doneButton.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get doneButton;

  /// No description provided for @workoutHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} History'**
  String workoutHistoryTitle(String name);

  /// No description provided for @historyTooltip.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTooltip;

  /// No description provided for @noSessionsYetTitle.
  ///
  /// In en, this message translates to:
  /// **'No sessions yet'**
  String get noSessionsYetTitle;

  /// No description provided for @noSessionsYetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Finish a workout for this day to start building its history.'**
  String get noSessionsYetSubtitle;

  /// No description provided for @sessionCompletedLabel.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get sessionCompletedLabel;

  /// No description provided for @sessionCancelledLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get sessionCancelledLabel;

  /// No description provided for @sessionInProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get sessionInProgressLabel;

  /// No description provided for @sessionDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get sessionDurationLabel;

  /// No description provided for @viewWorkoutTrackerButton.
  ///
  /// In en, this message translates to:
  /// **'View Workout Tracker'**
  String get viewWorkoutTrackerButton;

  /// No description provided for @programAnalyticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Program Analytics'**
  String get programAnalyticsTitle;

  /// No description provided for @analyticsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analyticsTooltip;

  /// No description provided for @noAnalyticsYetTitle.
  ///
  /// In en, this message translates to:
  /// **'No data yet'**
  String get noAnalyticsYetTitle;

  /// No description provided for @noAnalyticsYetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Finish a few workouts to start seeing trends here.'**
  String get noAnalyticsYetSubtitle;

  /// No description provided for @sessionsLoggedLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} sessions'**
  String sessionsLoggedLabel(int count);

  /// No description provided for @averageVolumeLabel.
  ///
  /// In en, this message translates to:
  /// **'Avg volume'**
  String get averageVolumeLabel;

  /// No description provided for @bestWeightLabel.
  ///
  /// In en, this message translates to:
  /// **'Best'**
  String get bestWeightLabel;

  /// No description provided for @noExercisesForDayYetBody.
  ///
  /// In en, this message translates to:
  /// **'No completed sessions for this day yet.'**
  String get noExercisesForDayYetBody;

  /// No description provided for @thisWeekTitle.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get thisWeekTitle;

  /// No description provided for @totalSessionsThisWeekLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} sessions completed'**
  String totalSessionsThisWeekLabel(int count);

  /// No description provided for @templateSessionsThisWeekLabel.
  ///
  /// In en, this message translates to:
  /// **'{count}×'**
  String templateSessionsThisWeekLabel(int count);

  /// No description provided for @restTimerLabel.
  ///
  /// In en, this message translates to:
  /// **'Rest Timer'**
  String get restTimerLabel;

  /// No description provided for @startRestTimerButton.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startRestTimerButton;

  /// No description provided for @stopRestTimerButton.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopRestTimerButton;

  /// No description provided for @resetRestTimerTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get resetRestTimerTooltip;

  /// No description provided for @setNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get setNotesHint;

  /// No description provided for @sessionNoteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Session Note'**
  String get sessionNoteTooltip;

  /// No description provided for @editSessionNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Session Note'**
  String get editSessionNoteTitle;

  /// No description provided for @sessionNoteHint.
  ///
  /// In en, this message translates to:
  /// **'How did this workout feel?'**
  String get sessionNoteHint;

  /// No description provided for @saveNoteButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveNoteButton;

  /// No description provided for @unableToSaveNoteError.
  ///
  /// In en, this message translates to:
  /// **'Unable to save the note.'**
  String get unableToSaveNoteError;

  /// No description provided for @consistencyTitle.
  ///
  /// In en, this message translates to:
  /// **'Consistency'**
  String get consistencyTitle;

  /// No description provided for @currentWeekStreakLabel.
  ///
  /// In en, this message translates to:
  /// **'Current streak'**
  String get currentWeekStreakLabel;

  /// No description provided for @weeksUnit.
  ///
  /// In en, this message translates to:
  /// **'{count} {count, plural, =1{week} other{weeks}}'**
  String weeksUnit(int count);

  /// No description provided for @longestWeekStreakLabel.
  ///
  /// In en, this message translates to:
  /// **'Longest streak'**
  String get longestWeekStreakLabel;

  /// No description provided for @averagePerWeekLabel.
  ///
  /// In en, this message translates to:
  /// **'Avg per week'**
  String get averagePerWeekLabel;

  /// No description provided for @daysSinceLastSessionLabel.
  ///
  /// In en, this message translates to:
  /// **'Last workout'**
  String get daysSinceLastSessionLabel;

  /// No description provided for @daysAgoLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} {count, plural, =0{days ago} =1{day ago} other{days ago}}'**
  String daysAgoLabel(int count);

  /// No description provided for @noConsistencyDataYetBody.
  ///
  /// In en, this message translates to:
  /// **'Complete a few workouts to see your consistency here.'**
  String get noConsistencyDataYetBody;

  /// No description provided for @kgUnit.
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get kgUnit;

  /// No description provided for @currentVsPreviousVolumeLabel.
  ///
  /// In en, this message translates to:
  /// **'{current} kg ({previous} kg last time)'**
  String currentVsPreviousVolumeLabel(String current, String previous);

  /// No description provided for @durationHoursMinutesLabel.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String durationHoursMinutesLabel(int hours, int minutes);

  /// No description provided for @durationMinutesOnlyLabel.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String durationMinutesOnlyLabel(int minutes);

  /// No description provided for @durationSecondsOnlyLabel.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String durationSecondsOnlyLabel(int seconds);

  /// No description provided for @exerciseBestLatestSummary.
  ///
  /// In en, this message translates to:
  /// **'Best: {bestWeight} kg  •  {latestVolume} kg latest'**
  String exerciseBestLatestSummary(String bestWeight, String latestVolume);

  /// No description provided for @homeCurrentProgramLabel.
  ///
  /// In en, this message translates to:
  /// **'Current Program'**
  String get homeCurrentProgramLabel;

  /// No description provided for @homeWorkoutsCompletedThisWeekLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} {count, plural, =0{workouts completed} =1{workout completed} other{workouts completed}}'**
  String homeWorkoutsCompletedThisWeekLabel(int count);

  /// No description provided for @homeOpenProgramButton.
  ///
  /// In en, this message translates to:
  /// **'Open Program'**
  String get homeOpenProgramButton;

  /// No description provided for @homeWorkoutInProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'Workout in Progress'**
  String get homeWorkoutInProgressLabel;

  /// No description provided for @homeStartedAgoLabel.
  ///
  /// In en, this message translates to:
  /// **'Started {duration} ago'**
  String homeStartedAgoLabel(String duration);

  /// No description provided for @homeRecentWorkoutsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent Workouts'**
  String get homeRecentWorkoutsTitle;

  /// No description provided for @homeExerciseCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} {count, plural, =1{Exercise} other{Exercises}}'**
  String homeExerciseCountLabel(int count);

  /// No description provided for @homeSetCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} {count, plural, =1{Set} other{Sets}}'**
  String homeSetCountLabel(int count);

  /// No description provided for @homeTotalVolumeLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Volume: {volume} kg'**
  String homeTotalVolumeLabel(String volume);

  /// No description provided for @homeViewSessionButton.
  ///
  /// In en, this message translates to:
  /// **'View Session'**
  String get homeViewSessionButton;

  /// No description provided for @homeShowExercisesButton.
  ///
  /// In en, this message translates to:
  /// **'Show exercises'**
  String get homeShowExercisesButton;

  /// No description provided for @homeHideExercisesButton.
  ///
  /// In en, this message translates to:
  /// **'Hide exercises'**
  String get homeHideExercisesButton;

  /// No description provided for @homeNoActiveProgramTitle.
  ///
  /// In en, this message translates to:
  /// **'No Active Program'**
  String get homeNoActiveProgramTitle;

  /// No description provided for @homeNoActiveProgramBody.
  ///
  /// In en, this message translates to:
  /// **'Create or activate a program to start tracking structured workouts.'**
  String get homeNoActiveProgramBody;

  /// No description provided for @homeNoRecentWorkoutsBody.
  ///
  /// In en, this message translates to:
  /// **'No completed workouts yet.'**
  String get homeNoRecentWorkoutsBody;

  /// No description provided for @startWorkoutFabLabel.
  ///
  /// In en, this message translates to:
  /// **'Start Workout'**
  String get startWorkoutFabLabel;

  /// No description provided for @deleteProgramConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this program permanently?'**
  String get deleteProgramConfirmTitle;

  /// No description provided for @deleteProgramConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete \"{name}\" and everything in it — every workout day, every session, every logged set. This cannot be undone.'**
  String deleteProgramConfirmBody(String name);

  /// No description provided for @deleteWorkoutDayConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this workout day permanently?'**
  String get deleteWorkoutDayConfirmTitle;

  /// No description provided for @deleteWorkoutDayConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete \"{name}\" and everything in it — every session, every logged set. This cannot be undone.'**
  String deleteWorkoutDayConfirmBody(String name);

  /// No description provided for @archivedWorkoutDaysTooltip.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get archivedWorkoutDaysTooltip;

  /// No description provided for @archivedWorkoutDaysTitle.
  ///
  /// In en, this message translates to:
  /// **'Archived Workout Days'**
  String get archivedWorkoutDaysTitle;

  /// No description provided for @noArchivedWorkoutDaysBody.
  ///
  /// In en, this message translates to:
  /// **'No archived workout days.'**
  String get noArchivedWorkoutDaysBody;

  /// No description provided for @restoreButton.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restoreButton;
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
