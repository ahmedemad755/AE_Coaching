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

  /// No description provided for @activeSessionOnly.
  ///
  /// In en, this message translates to:
  /// **'This Session Only'**
  String get activeSessionOnly;

  /// No description provided for @activeSessionAndProgram.
  ///
  /// In en, this message translates to:
  /// **'This Session + Program'**
  String get activeSessionAndProgram;

  /// No description provided for @activeExerciseScopeBody.
  ///
  /// In en, this message translates to:
  /// **'Update this workout now. Also update the program day only if you choose Session + Program.'**
  String get activeExerciseScopeBody;

  /// No description provided for @activeApplyEdit.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get activeApplyEdit;

  /// No description provided for @activeSessionEditSaved.
  ///
  /// In en, this message translates to:
  /// **'Session updated. Program unchanged.'**
  String get activeSessionEditSaved;

  /// No description provided for @activeProgramEditSaved.
  ///
  /// In en, this message translates to:
  /// **'Session and program day updated.'**
  String get activeProgramEditSaved;

  /// No description provided for @activeLoggedExerciseProtected.
  ///
  /// In en, this message translates to:
  /// **'This exercise has logged sets. Keep it to preserve your records; add another exercise instead. Targets and order can still be edited.'**
  String get activeLoggedExerciseProtected;

  /// No description provided for @activeProgramConflict.
  ///
  /// In en, this message translates to:
  /// **'The program day differs from this session. Use Session Only, or apply the program exercises before editing both.'**
  String get activeProgramConflict;

  /// No description provided for @activeProgramPending.
  ///
  /// In en, this message translates to:
  /// **'Session changes are saved, but the program update is unfinished. Retry to complete it. Stopping retries keeps your session and any program change already written.'**
  String get activeProgramPending;

  /// No description provided for @activeDuplicateExercise.
  ///
  /// In en, this message translates to:
  /// **'This exercise is already included. No duplicate was added.'**
  String get activeDuplicateExercise;

  /// No description provided for @activeWorkoutNoLongerActive.
  ///
  /// In en, this message translates to:
  /// **'This workout is no longer active. Reopen your current workout.'**
  String get activeWorkoutNoLongerActive;

  /// No description provided for @activeApplyProgram.
  ///
  /// In en, this message translates to:
  /// **'Apply program exercises'**
  String get activeApplyProgram;

  /// No description provided for @activeApplyProgramBody.
  ///
  /// In en, this message translates to:
  /// **'Program edits elsewhere affect future workouts only. Apply the current program day to this session now? This replaces session exercise edits and targets. Logged sets stay intact; changes that would remove a logged exercise are blocked.'**
  String get activeApplyProgramBody;

  /// No description provided for @activeRetryProgramEdit.
  ///
  /// In en, this message translates to:
  /// **'Retry program update'**
  String get activeRetryProgramEdit;

  /// No description provided for @activeKeepSessionEdit.
  ///
  /// In en, this message translates to:
  /// **'Keep changes and stop retrying'**
  String get activeKeepSessionEdit;

  /// No description provided for @appearanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceTitle;

  /// No description provided for @themeSystemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get themeSystemDefault;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themePreferenceSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save your appearance preference.'**
  String get themePreferenceSaveError;

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

  /// No description provided for @inactivityRemindersTitle.
  ///
  /// In en, this message translates to:
  /// **'Inactivity Reminders'**
  String get inactivityRemindersTitle;

  /// No description provided for @inactivityReminderSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save notification preference. Try again.'**
  String get inactivityReminderSaveFailed;

  /// No description provided for @repdbInstructions.
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get repdbInstructions;

  /// No description provided for @repdbPrimaryMuscles.
  ///
  /// In en, this message translates to:
  /// **'Primary muscles'**
  String get repdbPrimaryMuscles;

  /// No description provided for @repdbSecondaryMuscles.
  ///
  /// In en, this message translates to:
  /// **'Secondary muscles'**
  String get repdbSecondaryMuscles;

  /// No description provided for @repdbStartPosition.
  ///
  /// In en, this message translates to:
  /// **'Starting position'**
  String get repdbStartPosition;

  /// No description provided for @repdbPeakPosition.
  ///
  /// In en, this message translates to:
  /// **'Peak / end position'**
  String get repdbPeakPosition;

  /// No description provided for @repdbDataSources.
  ///
  /// In en, this message translates to:
  /// **'Credits and exercise data sources'**
  String get repdbDataSources;

  /// No description provided for @repdbSourceLicense.
  ///
  /// In en, this message translates to:
  /// **'RepDB Free Tier License'**
  String get repdbSourceLicense;

  /// No description provided for @repdbTranslationPending.
  ///
  /// In en, this message translates to:
  /// **'Arabic instructions are awaiting review. The original English instructions are shown below.'**
  String get repdbTranslationPending;

  /// No description provided for @repdbUnknownMetadata.
  ///
  /// In en, this message translates to:
  /// **'Not supplied by the source'**
  String get repdbUnknownMetadata;

  /// No description provided for @repdbFormCues.
  ///
  /// In en, this message translates to:
  /// **'Form cues'**
  String get repdbFormCues;

  /// No description provided for @repdbDatasetVersion.
  ///
  /// In en, this message translates to:
  /// **'Dataset version'**
  String get repdbDatasetVersion;

  /// No description provided for @repdbAddToWorkout.
  ///
  /// In en, this message translates to:
  /// **'Add to workout'**
  String get repdbAddToWorkout;

  /// No description provided for @repdbLegacyReference.
  ///
  /// In en, this message translates to:
  /// **'Legacy exercise. Choose a replacement from the new library if you want to update it.'**
  String get repdbLegacyReference;

  /// No description provided for @repdbResolveBeforeSave.
  ///
  /// In en, this message translates to:
  /// **'Replace the remaining legacy exercises before saving a new copy. Existing saved workouts are preserved.'**
  String get repdbResolveBeforeSave;

  /// No description provided for @homeGreetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get homeGreetingMorning;

  /// No description provided for @homeGreetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get homeGreetingAfternoon;

  /// No description provided for @homeGreetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get homeGreetingEvening;

  /// No description provided for @homeGreetingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ready for today\'s workout?'**
  String get homeGreetingSubtitle;

  /// No description provided for @homeDashboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Plan, train and track your progress'**
  String get homeDashboardSubtitle;

  /// No description provided for @homeManagePrograms.
  ///
  /// In en, this message translates to:
  /// **'Manage your programs'**
  String get homeManagePrograms;

  /// No description provided for @homeExploreTemplates.
  ///
  /// In en, this message translates to:
  /// **'Explore & save programs'**
  String get homeExploreTemplates;

  /// No description provided for @homeBeginSession.
  ///
  /// In en, this message translates to:
  /// **'Begin a training session'**
  String get homeBeginSession;

  /// No description provided for @homeProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get homeProgress;

  /// No description provided for @homeTrackResults.
  ///
  /// In en, this message translates to:
  /// **'Track your results'**
  String get homeTrackResults;

  /// No description provided for @homeQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get homeQuickActions;

  /// No description provided for @homeLogWorkout.
  ///
  /// In en, this message translates to:
  /// **'Log Workout'**
  String get homeLogWorkout;

  /// No description provided for @homeBodyMetrics.
  ///
  /// In en, this message translates to:
  /// **'Body Metrics'**
  String get homeBodyMetrics;

  /// No description provided for @homeNavigationHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeNavigationHome;

  /// No description provided for @homeNavigationPrograms.
  ///
  /// In en, this message translates to:
  /// **'Programs'**
  String get homeNavigationPrograms;

  /// No description provided for @homeNavigationMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get homeNavigationMore;

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

  /// No description provided for @progressSelectProgram.
  ///
  /// In en, this message translates to:
  /// **'Program'**
  String get progressSelectProgram;

  /// No description provided for @progressSelectWorkoutDay.
  ///
  /// In en, this message translates to:
  /// **'Workout day'**
  String get progressSelectWorkoutDay;

  /// No description provided for @progressSelectExercise.
  ///
  /// In en, this message translates to:
  /// **'Exercise'**
  String get progressSelectExercise;

  /// No description provided for @progressNoCompletedHistory.
  ///
  /// In en, this message translates to:
  /// **'No linked completed workout history yet.'**
  String get progressNoCompletedHistory;

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

  /// No description provided for @manageTemplateExercisesButton.
  ///
  /// In en, this message translates to:
  /// **'Manage exercises'**
  String get manageTemplateExercisesButton;

  /// No description provided for @manageTemplateExercisesTitle.
  ///
  /// In en, this message translates to:
  /// **'Exercises for {name}'**
  String manageTemplateExercisesTitle(String name);

  /// No description provided for @searchExerciseLibraryHint.
  ///
  /// In en, this message translates to:
  /// **'Search exercises'**
  String get searchExerciseLibraryHint;

  /// No description provided for @assignedTemplateExercisesTitle.
  ///
  /// In en, this message translates to:
  /// **'Workout plan'**
  String get assignedTemplateExercisesTitle;

  /// No description provided for @assignedTemplateExercisesCount.
  ///
  /// In en, this message translates to:
  /// **'Exercises · {count}'**
  String assignedTemplateExercisesCount(int count);

  /// No description provided for @noAssignedTemplateExercises.
  ///
  /// In en, this message translates to:
  /// **'No exercises assigned yet. Add exercises here so they are ready whenever you start this workout day.'**
  String get noAssignedTemplateExercises;

  /// No description provided for @exerciseLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Exercise library'**
  String get exerciseLibraryTitle;

  /// No description provided for @noExerciseSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No exercises match your search.'**
  String get noExerciseSearchResults;

  /// No description provided for @removeAssignedExerciseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove exercise from workout day'**
  String get removeAssignedExerciseTooltip;

  /// No description provided for @addAssignedExerciseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add exercise to workout day'**
  String get addAssignedExerciseTooltip;

  /// No description provided for @templateExerciseDuplicateError.
  ///
  /// In en, this message translates to:
  /// **'This exercise is already assigned.'**
  String get templateExerciseDuplicateError;

  /// No description provided for @templateExerciseSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save workout-day exercises.'**
  String get templateExerciseSaveError;

  /// No description provided for @exerciseLibraryLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load the exercise library.'**
  String get exerciseLibraryLoadError;

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

  /// No description provided for @discardEmptyWorkoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard this empty workout?'**
  String get discardEmptyWorkoutTitle;

  /// No description provided for @discardEmptyWorkoutBody.
  ///
  /// In en, this message translates to:
  /// **'No completed sets have been recorded. Keep training or discard this workout?'**
  String get discardEmptyWorkoutBody;

  /// No description provided for @keepTrainingButton.
  ///
  /// In en, this message translates to:
  /// **'Keep Training'**
  String get keepTrainingButton;

  /// No description provided for @discardWorkoutButton.
  ///
  /// In en, this message translates to:
  /// **'Discard Workout'**
  String get discardWorkoutButton;

  /// No description provided for @workoutCelebrationHeading.
  ///
  /// In en, this message translates to:
  /// **'Great work! 💪🔥'**
  String get workoutCelebrationHeading;

  /// No description provided for @workoutCelebrationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Workout complete. Every session brings you closer to your goal!'**
  String get workoutCelebrationSubtitle;

  /// No description provided for @completionExercisesLabel.
  ///
  /// In en, this message translates to:
  /// **'Exercises'**
  String get completionExercisesLabel;

  /// No description provided for @completionSetsLabel.
  ///
  /// In en, this message translates to:
  /// **'Sets'**
  String get completionSetsLabel;

  /// No description provided for @completionVolumeLabel.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get completionVolumeLabel;

  /// No description provided for @workoutDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get workoutDurationLabel;

  /// No description provided for @completionDurationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String completionDurationMinutes(int minutes);

  /// No description provided for @backToHomeButton.
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get backToHomeButton;

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

  /// No description provided for @analyticsSelectDay.
  ///
  /// In en, this message translates to:
  /// **'Workout day'**
  String get analyticsSelectDay;

  /// No description provided for @analyticsSelectExercise.
  ///
  /// In en, this message translates to:
  /// **'Exercise'**
  String get analyticsSelectExercise;

  /// No description provided for @analyticsWeightTitle.
  ///
  /// In en, this message translates to:
  /// **'Weight progression'**
  String get analyticsWeightTitle;

  /// No description provided for @analyticsRepsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reps progression'**
  String get analyticsRepsTitle;

  /// No description provided for @analyticsVolumeTitle.
  ///
  /// In en, this message translates to:
  /// **'Training volume progression'**
  String get analyticsVolumeTitle;

  /// No description provided for @analyticsRepsUnit.
  ///
  /// In en, this message translates to:
  /// **'reps'**
  String get analyticsRepsUnit;

  /// No description provided for @analyticsVolumeUnit.
  ///
  /// In en, this message translates to:
  /// **'kg × reps'**
  String get analyticsVolumeUnit;

  /// No description provided for @analyticsRepsAtWeight.
  ///
  /// In en, this message translates to:
  /// **'Best reps at {weight} kg'**
  String analyticsRepsAtWeight(String weight);

  /// No description provided for @analyticsPreviousValue.
  ///
  /// In en, this message translates to:
  /// **'Previous ({date}): {value} {unit}'**
  String analyticsPreviousValue(String date, String value, String unit);

  /// No description provided for @analyticsLatestValue.
  ///
  /// In en, this message translates to:
  /// **'Latest ({date}): {value} {unit}'**
  String analyticsLatestValue(String date, String value, String unit);

  /// No description provided for @analyticsAbsoluteChange.
  ///
  /// In en, this message translates to:
  /// **'Change: {change} {unit}'**
  String analyticsAbsoluteChange(String change, String unit);

  /// No description provided for @analyticsPercentChange.
  ///
  /// In en, this message translates to:
  /// **'Change: {change}%'**
  String analyticsPercentChange(String change);

  /// No description provided for @analyticsPercentageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Percentage change unavailable from a zero baseline.'**
  String get analyticsPercentageUnavailable;

  /// No description provided for @analyticsNeedMoreSessions.
  ///
  /// In en, this message translates to:
  /// **'Complete at least two sessions with this exercise to compare progression.'**
  String get analyticsNeedMoreSessions;

  /// No description provided for @analyticsNoComparableReps.
  ///
  /// In en, this message translates to:
  /// **'No shared weight appears in the latest two sessions, so reps cannot be compared.'**
  String get analyticsNoComparableReps;

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

  /// No description provided for @restDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Rest duration'**
  String get restDurationLabel;

  /// No description provided for @restMinutesLabel.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get restMinutesLabel;

  /// No description provided for @restSecondsLabel.
  ///
  /// In en, this message translates to:
  /// **'sec'**
  String get restSecondsLabel;

  /// No description provided for @setDoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get setDoneLabel;

  /// No description provided for @waitForRestTimerLabel.
  ///
  /// In en, this message translates to:
  /// **'Wait until the rest timer finishes.'**
  String get waitForRestTimerLabel;

  /// No description provided for @markPreviousSetDoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Mark the previous set done to start rest.'**
  String get markPreviousSetDoneLabel;

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

  /// No description provided for @homeWorkoutPlansTitle.
  ///
  /// In en, this message translates to:
  /// **'My Workout Plans'**
  String get homeWorkoutPlansTitle;

  /// No description provided for @homeViewAllPlansButton.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get homeViewAllPlansButton;

  /// No description provided for @homeNoWorkoutPlansBody.
  ///
  /// In en, this message translates to:
  /// **'Create your first workout plan to organize your training days.'**
  String get homeNoWorkoutPlansBody;

  /// No description provided for @homeCreateWorkoutPlanButton.
  ///
  /// In en, this message translates to:
  /// **'Create a workout plan'**
  String get homeCreateWorkoutPlanButton;

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

  /// No description provided for @exercisePickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Select exercises'**
  String get exercisePickerTitle;

  /// No description provided for @exerciseFiltersTitle.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get exerciseFiltersTitle;

  /// No description provided for @muscleGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Muscle group'**
  String get muscleGroupLabel;

  /// No description provided for @equipmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get equipmentLabel;

  /// No description provided for @createCustomExerciseButton.
  ///
  /// In en, this message translates to:
  /// **'Create custom exercise'**
  String get createCustomExerciseButton;

  /// No description provided for @addSelectedExercisesButton.
  ///
  /// In en, this message translates to:
  /// **'Add selected ({count})'**
  String addSelectedExercisesButton(int count);

  /// No description provided for @customExerciseDuplicateError.
  ///
  /// In en, this message translates to:
  /// **'An exercise with this name already exists.'**
  String get customExerciseDuplicateError;

  /// No description provided for @customExerciseSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save the custom exercise.'**
  String get customExerciseSaveError;

  /// No description provided for @createCustomExerciseTitle.
  ///
  /// In en, this message translates to:
  /// **'Create custom exercise'**
  String get createCustomExerciseTitle;

  /// No description provided for @exerciseNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Exercise name'**
  String get exerciseNameLabel;

  /// No description provided for @muscleGroupOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Muscle group (optional)'**
  String get muscleGroupOptionalLabel;

  /// No description provided for @equipmentOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Equipment (optional)'**
  String get equipmentOptionalLabel;

  /// No description provided for @addExerciseButton.
  ///
  /// In en, this message translates to:
  /// **'Add exercise'**
  String get addExerciseButton;

  /// No description provided for @addExerciseToTitle.
  ///
  /// In en, this message translates to:
  /// **'Add exercises to'**
  String get addExerciseToTitle;

  /// No description provided for @addExerciseToBody.
  ///
  /// In en, this message translates to:
  /// **'Choose whether these exercises belong only to this workout or should be saved to the workout day for next time.'**
  String get addExerciseToBody;

  /// No description provided for @currentSessionOnlyAction.
  ///
  /// In en, this message translates to:
  /// **'This workout only'**
  String get currentSessionOnlyAction;

  /// No description provided for @saveToWorkoutDayAction.
  ///
  /// In en, this message translates to:
  /// **'Save to workout day'**
  String get saveToWorkoutDayAction;

  /// No description provided for @exerciseLibrarySaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not add the selected exercises.'**
  String get exerciseLibrarySaveError;

  /// No description provided for @newExerciseButton.
  ///
  /// In en, this message translates to:
  /// **'Add exercise'**
  String get newExerciseButton;

  /// No description provided for @sessionOnlyExerciseLabel.
  ///
  /// In en, this message translates to:
  /// **'Added to this workout only'**
  String get sessionOnlyExerciseLabel;

  /// No description provided for @replaceExerciseAction.
  ///
  /// In en, this message translates to:
  /// **'Replace exercise'**
  String get replaceExerciseAction;

  /// No description provided for @removeExerciseAction.
  ///
  /// In en, this message translates to:
  /// **'Remove exercise'**
  String get removeExerciseAction;

  /// No description provided for @exerciseChangeDestinationTitle.
  ///
  /// In en, this message translates to:
  /// **'Where should this change apply?'**
  String get exerciseChangeDestinationTitle;

  /// No description provided for @exerciseChangeDestinationBody.
  ///
  /// In en, this message translates to:
  /// **'Choose this workout only, or save the change to the workout day for future sessions. Saving to the workout day will not change this active workout.'**
  String get exerciseChangeDestinationBody;

  /// No description provided for @exerciseChangeFutureOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'Saving to the workout day affects future sessions only. This current workout stays unchanged.'**
  String get exerciseChangeFutureOnlyNote;

  /// No description provided for @removeExerciseLoggedSetsBody.
  ///
  /// In en, this message translates to:
  /// **'{name} has {count} recorded sets. Removing it only hides the exercise from this session; the sets remain in workout history and totals.'**
  String removeExerciseLoggedSetsBody(Object name, int count);

  /// No description provided for @personalHubTitle.
  ///
  /// In en, this message translates to:
  /// **'Personal Hub'**
  String get personalHubTitle;

  /// No description provided for @profileHeaderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your training and account in one place'**
  String get profileHeaderSubtitle;

  /// No description provided for @profileEditName.
  ///
  /// In en, this message translates to:
  /// **'Edit name'**
  String get profileEditName;

  /// No description provided for @profilePhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get profilePhoneLabel;

  /// No description provided for @profileAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get profileAddPhoto;

  /// No description provided for @profileChangePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get profileChangePhoto;

  /// No description provided for @profileRemovePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get profileRemovePhoto;

  /// No description provided for @profilePhotoPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Preview profile photo'**
  String get profilePhotoPreviewTitle;

  /// No description provided for @profilePhotoSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile photo saved.'**
  String get profilePhotoSaved;

  /// No description provided for @profilePhotoRemoved.
  ///
  /// In en, this message translates to:
  /// **'Profile photo removed.'**
  String get profilePhotoRemoved;

  /// No description provided for @profilePhotoSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the profile photo. Try another image.'**
  String get profilePhotoSaveFailed;

  /// No description provided for @profilePhotoRemoveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not remove the profile photo. Try again.'**
  String get profilePhotoRemoveFailed;

  /// No description provided for @profilePhotoRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove only this profile photo? Your account and workout data will stay unchanged.'**
  String get profilePhotoRemoveConfirm;

  /// No description provided for @profileNameSaved.
  ///
  /// In en, this message translates to:
  /// **'Your name was updated.'**
  String get profileNameSaved;

  /// No description provided for @profileNameSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update your name. Check your connection and try again.'**
  String get profileNameSaveFailed;

  /// No description provided for @profilePhoneVerificationNote.
  ///
  /// In en, this message translates to:
  /// **'Changing a phone number requires SMS verification.'**
  String get profilePhoneVerificationNote;

  /// No description provided for @profileProgressAction.
  ///
  /// In en, this message translates to:
  /// **'My progress'**
  String get profileProgressAction;

  /// No description provided for @appSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'App settings'**
  String get appSettingsTitle;

  /// No description provided for @myProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'My progress'**
  String get myProgressTitle;

  /// No description provided for @progressCompletedWorkoutsLabel.
  ///
  /// In en, this message translates to:
  /// **'Completed workouts'**
  String get progressCompletedWorkoutsLabel;

  /// No description provided for @progressThisWeekLabel.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get progressThisWeekLabel;

  /// No description provided for @progressThisMonthLabel.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get progressThisMonthLabel;

  /// No description provided for @progressWeeklyActivity.
  ///
  /// In en, this message translates to:
  /// **'Weekly activity'**
  String get progressWeeklyActivity;

  /// No description provided for @progressPersonalRecords.
  ///
  /// In en, this message translates to:
  /// **'Personal records'**
  String get progressPersonalRecords;

  /// No description provided for @progressHeaviestWeightRecord.
  ///
  /// In en, this message translates to:
  /// **'Heaviest weight'**
  String get progressHeaviestWeightRecord;

  /// No description provided for @progressHighestSetVolumeRecord.
  ///
  /// In en, this message translates to:
  /// **'Highest set volume'**
  String get progressHighestSetVolumeRecord;

  /// No description provided for @progressProgramAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Program analytics'**
  String get progressProgramAnalytics;

  /// No description provided for @progressRecentWorkouts.
  ///
  /// In en, this message translates to:
  /// **'Workout history'**
  String get progressRecentWorkouts;

  /// No description provided for @progressNoCompletedWorkouts.
  ///
  /// In en, this message translates to:
  /// **'Completed workouts will appear here after you finish a workout.'**
  String get progressNoCompletedWorkouts;

  /// No description provided for @progressDataUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Your workout progress could not be loaded right now.'**
  String get progressDataUnavailable;

  /// No description provided for @profileNameUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Name not available'**
  String get profileNameUnavailable;

  /// No description provided for @profileNameInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a name up to 80 characters.'**
  String get profileNameInvalid;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications and reminders'**
  String get settingsNotifications;

  /// No description provided for @settingsNotificationAuthorized.
  ///
  /// In en, this message translates to:
  /// **'Device notifications are allowed'**
  String get settingsNotificationAuthorized;

  /// No description provided for @settingsNotificationDenied.
  ///
  /// In en, this message translates to:
  /// **'Device notifications are turned off'**
  String get settingsNotificationDenied;

  /// No description provided for @settingsNotificationNotRequested.
  ///
  /// In en, this message translates to:
  /// **'Device notification permission has not been requested'**
  String get settingsNotificationNotRequested;

  /// No description provided for @settingsNotificationPermissionNote.
  ///
  /// In en, this message translates to:
  /// **'The workout reminder switch is separate from your phone\'s notification permission.'**
  String get settingsNotificationPermissionNote;

  /// No description provided for @settingsPermissionHelpAction.
  ///
  /// In en, this message translates to:
  /// **'How to enable notifications'**
  String get settingsPermissionHelpAction;

  /// No description provided for @settingsPermissionHelpBody.
  ///
  /// In en, this message translates to:
  /// **'Open your phone settings, choose Apps, select AE Coaching, then allow Notifications.'**
  String get settingsPermissionHelpBody;

  /// No description provided for @settingsLogoutDescription.
  ///
  /// In en, this message translates to:
  /// **'Sign out of this device. Your saved workouts and account data will remain.'**
  String get settingsLogoutDescription;

  /// No description provided for @profileNameEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit your name'**
  String get profileNameEditTitle;

  /// No description provided for @exercisePickerAlternateTitle.
  ///
  /// In en, this message translates to:
  /// **'اختر التمارين'**
  String get exercisePickerAlternateTitle;

  /// No description provided for @exerciseIllustrationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No illustration yet'**
  String get exerciseIllustrationUnavailable;

  /// No description provided for @exercisePreviewAction.
  ///
  /// In en, this message translates to:
  /// **'Preview exercise'**
  String get exercisePreviewAction;

  /// No description provided for @exerciseCustomBadge.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get exerciseCustomBadge;

  /// No description provided for @exerciseAllFilter.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get exerciseAllFilter;

  /// No description provided for @exerciseWatchVideo.
  ///
  /// In en, this message translates to:
  /// **'Watch on MuscleWiki (external browser)'**
  String get exerciseWatchVideo;

  /// No description provided for @exerciseBrowserLaunchFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the browser. Please try again.'**
  String get exerciseBrowserLaunchFailed;

  /// No description provided for @exerciseArtworkCredits.
  ///
  /// In en, this message translates to:
  /// **'Illustration credits'**
  String get exerciseArtworkCredits;

  /// No description provided for @exerciseArtworkSource.
  ///
  /// In en, this message translates to:
  /// **'View illustration source'**
  String get exerciseArtworkSource;

  /// No description provided for @exerciseArtworkLicense.
  ///
  /// In en, this message translates to:
  /// **'Read illustration license (offline)'**
  String get exerciseArtworkLicense;

  /// No description provided for @exerciseMuscleName.
  ///
  /// In en, this message translates to:
  /// **'{muscle, select, chest {Chest} back {Back} shoulders {Shoulders} biceps {Biceps} triceps {Triceps} quadriceps {Quadriceps} hamstrings_glutes {Hamstrings / glutes} calves {Calves} abs_core {Abs / core} full_body {Full body} other {{muscle}}}'**
  String exerciseMuscleName(String muscle);

  /// No description provided for @exerciseEquipmentName.
  ///
  /// In en, this message translates to:
  /// **'{equipment, select, barbell {Barbell} dumbbell {Dumbbell} cable {Cable} machine {Machine} bodyweight {Bodyweight} smith_machine {Smith machine} ez_bar {EZ bar} kettlebell {Kettlebell} plate {Plate} trap_bar {Trap bar} ab_wheel {Ab wheel} other {{equipment}}}'**
  String exerciseEquipmentName(String equipment);

  /// No description provided for @workoutTemplatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Workout Templates'**
  String get workoutTemplatesTitle;

  /// No description provided for @standardTemplatesIntro.
  ///
  /// In en, this message translates to:
  /// **'Choose a split, preview its days, then customize your own copy.'**
  String get standardTemplatesIntro;

  /// No description provided for @useWorkoutTemplate.
  ///
  /// In en, this message translates to:
  /// **'Use Template'**
  String get useWorkoutTemplate;

  /// No description provided for @customizeTemplateTitle.
  ///
  /// In en, this message translates to:
  /// **'Customize Program'**
  String get customizeTemplateTitle;

  /// No description provided for @saveToMyPrograms.
  ///
  /// In en, this message translates to:
  /// **'Save to My Programs'**
  String get saveToMyPrograms;

  /// No description provided for @standardTemplateSaved.
  ///
  /// In en, this message translates to:
  /// **'Program saved to My Programs.'**
  String get standardTemplateSaved;

  /// No description provided for @standardTemplateSavedLocally.
  ///
  /// In en, this message translates to:
  /// **'Program saved on this device. Cloud backup is incomplete; reopen My Programs and the program\'s days when connected.'**
  String get standardTemplateSavedLocally;

  /// No description provided for @standardTemplateLoadError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load workout templates.'**
  String get standardTemplateLoadError;

  /// No description provided for @standardTemplatesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No workout templates are available.'**
  String get standardTemplatesEmpty;

  /// No description provided for @standardTemplateProgrammingNote.
  ///
  /// In en, this message translates to:
  /// **'Working sets exclude warm-ups. Start with loads that leave about 1–3 reps in reserve. Use the lower end of the volume if needed, add load gradually within the rep range, and allow recovery. Rest longer when needed. These are adjustable starting plans, not individualized prescriptions.'**
  String get standardTemplateProgrammingNote;

  /// No description provided for @standardTemplateAdvancedNote.
  ///
  /// In en, this message translates to:
  /// **'Six training days suit experienced lifters with enough recovery. A/B sessions share the weekly workload; they are not two copies of the three-day plan. Add rest days if recovery suffers.'**
  String get standardTemplateAdvancedNote;

  /// No description provided for @standardTemplateAnteriorPosteriorNote.
  ///
  /// In en, this message translates to:
  /// **'A practical emphasis split: anterior days focus on chest, quads, delts, biceps and abs; posterior days focus on back, hamstrings, glutes, rear delts, triceps and calves. Movements naturally overlap.'**
  String get standardTemplateAnteriorPosteriorNote;

  /// No description provided for @suggestedTrainingWeek.
  ///
  /// In en, this message translates to:
  /// **'Suggested seven-day sequence'**
  String get suggestedTrainingWeek;

  /// No description provided for @standardRestDay.
  ///
  /// In en, this message translates to:
  /// **'Rest'**
  String get standardRestDay;

  /// No description provided for @workingSetsLabel.
  ///
  /// In en, this message translates to:
  /// **'Working sets'**
  String get workingSetsLabel;

  /// No description provided for @minimumRepsLabel.
  ///
  /// In en, this message translates to:
  /// **'Minimum reps'**
  String get minimumRepsLabel;

  /// No description provided for @maximumRepsLabel.
  ///
  /// In en, this message translates to:
  /// **'Maximum reps'**
  String get maximumRepsLabel;

  /// No description provided for @exerciseRestSecondsLabel.
  ///
  /// In en, this message translates to:
  /// **'Rest (seconds)'**
  String get exerciseRestSecondsLabel;

  /// No description provided for @editExerciseTargets.
  ///
  /// In en, this message translates to:
  /// **'Edit sets, reps & rest'**
  String get editExerciseTargets;

  /// No description provided for @exerciseTargetsValidation.
  ///
  /// In en, this message translates to:
  /// **'Use 1–10 sets, 1–100 reps (minimum ≤ maximum) and 15–600 seconds rest.'**
  String get exerciseTargetsValidation;

  /// No description provided for @standardDraftInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a program name, name every day, and keep at least one exercise in each day. Check exercise targets.'**
  String get standardDraftInvalid;

  /// No description provided for @standardDraftSaveError.
  ///
  /// In en, this message translates to:
  /// **'Unable to save the program. Your draft is still available; try again.'**
  String get standardDraftSaveError;

  /// No description provided for @standardDraftAccountChanged.
  ///
  /// In en, this message translates to:
  /// **'The account changed. Reopen Workout Templates for the current account.'**
  String get standardDraftAccountChanged;

  /// No description provided for @discardProgramDraftTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard this draft?'**
  String get discardProgramDraftTitle;

  /// No description provided for @discardProgramDraftBody.
  ///
  /// In en, this message translates to:
  /// **'This program has not been saved. Leaving will discard your customizations.'**
  String get discardProgramDraftBody;

  /// No description provided for @discardProgramDraft.
  ///
  /// In en, this message translates to:
  /// **'Discard draft'**
  String get discardProgramDraft;

  /// No description provided for @templateDaysPerWeek.
  ///
  /// In en, this message translates to:
  /// **'{count} days / week'**
  String templateDaysPerWeek(int count);

  /// No description provided for @suggestedSequenceDay.
  ///
  /// In en, this message translates to:
  /// **'Day {day}'**
  String suggestedSequenceDay(int day);

  /// No description provided for @exerciseTargetSummary.
  ///
  /// In en, this message translates to:
  /// **'Plan: {sets} sets × {min}–{max} reps · rest {seconds}s'**
  String exerciseTargetSummary(int sets, int min, int max, int seconds);
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
