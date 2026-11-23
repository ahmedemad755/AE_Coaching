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

  /// No description provided for @inactivityRemindersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A gentle nudge when you haven\'t logged a workout for a while.'**
  String get inactivityRemindersSubtitle;

  /// No description provided for @inactivityReminderLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading your reminder setting…'**
  String get inactivityReminderLoading;

  /// No description provided for @inactivityReminderSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving reminder setting…'**
  String get inactivityReminderSaving;

  /// No description provided for @inactivityReminderSaved.
  ///
  /// In en, this message translates to:
  /// **'Reminder setting saved.'**
  String get inactivityReminderSaved;

  /// No description provided for @inactivityReminderSavedOffline.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device. It will sync when you\'re back online.'**
  String get inactivityReminderSavedOffline;

  /// No description provided for @inactivityReminderPendingSync.
  ///
  /// In en, this message translates to:
  /// **'Waiting to sync. Your change isn\'t confirmed yet.'**
  String get inactivityReminderPendingSync;

  /// No description provided for @inactivityReminderOffline.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Connect to load your reminder setting.'**
  String get inactivityReminderOffline;

  /// No description provided for @inactivityReminderUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Verify your email to manage workout reminders.'**
  String get inactivityReminderUnavailable;

  /// No description provided for @inactivityReminderLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your reminder setting.'**
  String get inactivityReminderLoadFailed;

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

  /// No description provided for @createAccountButton.
  ///
  /// In en, this message translates to:
  /// **'CREATE ACCOUNT'**
  String get createAccountButton;

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

  /// No description provided for @sessionCheckingMessage.
  ///
  /// In en, this message translates to:
  /// **'Checking your account...'**
  String get sessionCheckingMessage;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get forgotPasswordTitle;

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

  /// No description provided for @profileEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get profileEmailLabel;

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
  /// **'Enter a name of up to 60 characters that includes at least one letter.'**
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

  /// No description provided for @loadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loadingLabel;

  /// No description provided for @resendCodeIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String resendCodeIn(int seconds);

  /// No description provided for @signOutUseAnotherAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign out and use another account'**
  String get signOutUseAnotherAccount;

  /// No description provided for @leaveVerificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave verification?'**
  String get leaveVerificationTitle;

  /// No description provided for @signOutButton.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOutButton;

  /// No description provided for @stayButton.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get stayButton;

  /// No description provided for @verificationInProgressMessage.
  ///
  /// In en, this message translates to:
  /// **'Please wait until verification finishes.'**
  String get verificationInProgressMessage;

  /// No description provided for @sessionCheckFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t check your account'**
  String get sessionCheckFailedTitle;

  /// No description provided for @sessionCheckFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection and try again.'**
  String get sessionCheckFailedBody;

  /// No description provided for @nameTooLong.
  ///
  /// In en, this message translates to:
  /// **'Name must be {max} characters or fewer'**
  String nameTooLong(int max);

  /// No description provided for @nameNeedsLetters.
  ///
  /// In en, this message translates to:
  /// **'Name must include letters'**
  String get nameNeedsLetters;

  /// No description provided for @passwordMinLengthError.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least {min} characters'**
  String passwordMinLengthError(int min);

  /// No description provided for @passwordMaxLengthError.
  ///
  /// In en, this message translates to:
  /// **'Password must be {max} characters or fewer'**
  String passwordMaxLengthError(int max);

  /// No description provided for @passwordEdgeWhitespaceError.
  ///
  /// In en, this message translates to:
  /// **'Password can\'t start or end with a space'**
  String get passwordEdgeWhitespaceError;

  /// No description provided for @passwordRequirementsHelper.
  ///
  /// In en, this message translates to:
  /// **'At least {min} characters'**
  String passwordRequirementsHelper(int min);

  /// No description provided for @showPasswordTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPasswordTooltip;

  /// No description provided for @hidePasswordTooltip.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePasswordTooltip;

  /// No description provided for @changePasswordAction.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePasswordAction;

  /// No description provided for @authErrorWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Please choose a stronger password (at least 6 characters).'**
  String get authErrorWeakPassword;

  /// No description provided for @authErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection and try again.'**
  String get authErrorNetwork;

  /// No description provided for @authErrorTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please try again later.'**
  String get authErrorTooManyRequests;

  /// No description provided for @authErrorAccountDisabled.
  ///
  /// In en, this message translates to:
  /// **'This account has been disabled. Please contact support.'**
  String get authErrorAccountDisabled;

  /// No description provided for @authErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get authErrorGeneric;

  /// No description provided for @authErrorInvalidName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid name.'**
  String get authErrorInvalidName;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailHint;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address'**
  String get emailRequired;

  /// No description provided for @emailInvalidError.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get emailInvalidError;

  /// No description provided for @emailTooLongError.
  ///
  /// In en, this message translates to:
  /// **'Email address is too long'**
  String get emailTooLongError;

  /// No description provided for @emailReservedError.
  ///
  /// In en, this message translates to:
  /// **'This email address can\'t be used'**
  String get emailReservedError;

  /// No description provided for @verifyEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get verifyEmailTitle;

  /// No description provided for @verifyEmailBody.
  ///
  /// In en, this message translates to:
  /// **'We sent a verification link to {email}. Open it, then come back and tap \"I\'ve verified\".'**
  String verifyEmailBody(String email);

  /// No description provided for @verifyEmailNotSentBody.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t send the verification email to {email}. Tap Resend to try again.'**
  String verifyEmailNotSentBody(String email);

  /// No description provided for @verifyEmailSpamHint.
  ///
  /// In en, this message translates to:
  /// **'Can\'t find it? Check your spam or junk folder.'**
  String get verifyEmailSpamHint;

  /// No description provided for @iveVerifiedButton.
  ///
  /// In en, this message translates to:
  /// **'I\'VE VERIFIED'**
  String get iveVerifiedButton;

  /// No description provided for @resendEmailButton.
  ///
  /// In en, this message translates to:
  /// **'RESEND EMAIL'**
  String get resendEmailButton;

  /// No description provided for @verificationEmailSentMessage.
  ///
  /// In en, this message translates to:
  /// **'Verification email sent.'**
  String get verificationEmailSentMessage;

  /// No description provided for @emailNotVerifiedYetMessage.
  ///
  /// In en, this message translates to:
  /// **'Your email isn\'t verified yet. Open the link we sent, then try again.'**
  String get emailNotVerifiedYetMessage;

  /// No description provided for @changeEmailButton.
  ///
  /// In en, this message translates to:
  /// **'Change email'**
  String get changeEmailButton;

  /// No description provided for @changeEmailBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ll send a verification link to the new address. Your sign-in email changes after you open it.'**
  String get changeEmailBody;

  /// No description provided for @newEmailHint.
  ///
  /// In en, this message translates to:
  /// **'New email'**
  String get newEmailHint;

  /// No description provided for @sendLinkButton.
  ///
  /// In en, this message translates to:
  /// **'Send link'**
  String get sendLinkButton;

  /// No description provided for @emailChangeRequestedMessage.
  ///
  /// In en, this message translates to:
  /// **'Verification link sent to {email}. Open it to finish changing your email.'**
  String emailChangeRequestedMessage(String email);

  /// No description provided for @emailVerifiedSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Email verified successfully'**
  String get emailVerifiedSuccessMessage;

  /// No description provided for @accountSetupCompleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Account setup complete'**
  String get accountSetupCompleteMessage;

  /// No description provided for @legacyAccountSignedOutMessage.
  ///
  /// In en, this message translates to:
  /// **'This test account is no longer supported. Please create a new account with your email.'**
  String get legacyAccountSignedOutMessage;

  /// No description provided for @leaveEmailVerificationBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ll be signed out. Log in again any time to finish verifying your email.'**
  String get leaveEmailVerificationBody;

  /// No description provided for @forgotPasswordEmailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your account email and we\'ll send you a link to reset your password.'**
  String get forgotPasswordEmailSubtitle;

  /// No description provided for @sendResetLinkButton.
  ///
  /// In en, this message translates to:
  /// **'SEND RESET LINK'**
  String get sendResetLinkButton;

  /// No description provided for @passwordResetEmailSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get passwordResetEmailSentTitle;

  /// No description provided for @passwordResetEmailSentBody.
  ///
  /// In en, this message translates to:
  /// **'If an account exists for {email}, we\'ve sent a link to reset your password.'**
  String passwordResetEmailSentBody(String email);

  /// No description provided for @backToLoginButton.
  ///
  /// In en, this message translates to:
  /// **'Back to login'**
  String get backToLoginButton;

  /// No description provided for @authErrorIncorrectEmailCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password.'**
  String get authErrorIncorrectEmailCredentials;

  /// No description provided for @authErrorEmailInUse.
  ///
  /// In en, this message translates to:
  /// **'An account already exists for this email. Please log in instead.'**
  String get authErrorEmailInUse;

  /// No description provided for @authErrorNewEmailInUse.
  ///
  /// In en, this message translates to:
  /// **'This email address is already used by another account.'**
  String get authErrorNewEmailInUse;

  /// No description provided for @authErrorRecentLoginEmail.
  ///
  /// In en, this message translates to:
  /// **'For your security, please sign in again to change your email.'**
  String get authErrorRecentLoginEmail;

  /// No description provided for @authErrorSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please sign in again.'**
  String get authErrorSessionExpired;

  /// No description provided for @authErrorSessionEnded.
  ///
  /// In en, this message translates to:
  /// **'Your session has ended. Please sign in again.'**
  String get authErrorSessionEnded;

  /// No description provided for @accountSetupFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t finish setting up your account'**
  String get accountSetupFailedTitle;

  /// No description provided for @profilePermissionDeniedBody.
  ///
  /// In en, this message translates to:
  /// **'Access to your account profile was denied. Please try again later, or contact support if this continues.'**
  String get profilePermissionDeniedBody;

  /// No description provided for @profileConflictingBody.
  ///
  /// In en, this message translates to:
  /// **'Your account profile needs attention. Please contact support.'**
  String get profileConflictingBody;

  /// No description provided for @profileUnknownFailureBody.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong while setting up your account. Please try again.'**
  String get profileUnknownFailureBody;

  /// No description provided for @authErrorProfilePermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t save your profile because access was denied. Please contact support.'**
  String get authErrorProfilePermissionDenied;

  /// No description provided for @authErrorProfileConflicting.
  ///
  /// In en, this message translates to:
  /// **'Your account profile needs attention. Please contact support.'**
  String get authErrorProfileConflicting;

  /// No description provided for @feedbackDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get feedbackDismiss;

  /// No description provided for @feedbackSuccessLabel.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get feedbackSuccessLabel;

  /// No description provided for @feedbackErrorLabel.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get feedbackErrorLabel;

  /// No description provided for @feedbackWarningLabel.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get feedbackWarningLabel;

  /// No description provided for @feedbackInfoLabel.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get feedbackInfoLabel;

  /// No description provided for @feedbackLoadingLabel.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get feedbackLoadingLabel;

  /// No description provided for @feedbackGenericError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get feedbackGenericError;

  /// No description provided for @feedbackSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Your session has ended. Please sign in again.'**
  String get feedbackSignInRequired;

  /// No description provided for @feedbackItemUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This item is no longer available. Refresh and try again.'**
  String get feedbackItemUnavailable;

  /// No description provided for @logoutFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Logout failed. Please try again.'**
  String get logoutFailedMessage;

  /// No description provided for @feedbackWorkoutNotActive.
  ///
  /// In en, this message translates to:
  /// **'This workout is no longer active.'**
  String get feedbackWorkoutNotActive;

  /// No description provided for @dangerZoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Danger zone'**
  String get dangerZoneTitle;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete your account and its data'**
  String get deleteAccountEntrySubtitle;

  /// No description provided for @deleteAccountIntro.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account permanently removes:'**
  String get deleteAccountIntro;

  /// No description provided for @deleteAccountItemWorkouts.
  ///
  /// In en, this message translates to:
  /// **'Your workouts, sets, sessions and programs'**
  String get deleteAccountItemWorkouts;

  /// No description provided for @deleteAccountItemMeasurements.
  ///
  /// In en, this message translates to:
  /// **'Your body measurements and progress photos'**
  String get deleteAccountItemMeasurements;

  /// No description provided for @deleteAccountItemProfile.
  ///
  /// In en, this message translates to:
  /// **'Your profile, settings and notification devices'**
  String get deleteAccountItemProfile;

  /// No description provided for @deleteAccountIrreversible.
  ///
  /// In en, this message translates to:
  /// **'This can\'t be undone. Your account and all its data are deleted right away.'**
  String get deleteAccountIrreversible;

  /// No description provided for @deleteAccountPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Enter your password to confirm'**
  String get deleteAccountPasswordLabel;

  /// No description provided for @deleteAccountConfirmCheckbox.
  ///
  /// In en, this message translates to:
  /// **'I understand that my account and all its data will be permanently deleted.'**
  String get deleteAccountConfirmCheckbox;

  /// No description provided for @deleteAccountSubmit.
  ///
  /// In en, this message translates to:
  /// **'Delete my account permanently'**
  String get deleteAccountSubmit;

  /// No description provided for @deleteAccountSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account…'**
  String get deleteAccountSubmitting;

  /// No description provided for @deleteAccountWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password. Try again.'**
  String get deleteAccountWrongPassword;

  /// No description provided for @deleteAccountTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a few minutes and try again.'**
  String get deleteAccountTooManyAttempts;

  /// No description provided for @deleteAccountOffline.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Connect to the internet to delete your account.'**
  String get deleteAccountOffline;

  /// No description provided for @deleteAccountReauthRequired.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again, then retry.'**
  String get deleteAccountReauthRequired;

  /// No description provided for @deleteAccountUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Account deletion isn\'t available for this sign-in method. Please contact support.'**
  String get deleteAccountUnsupported;

  /// No description provided for @deleteAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t finish deleting your account. Try again.'**
  String get deleteAccountFailed;

  /// No description provided for @accountDeletedNotice.
  ///
  /// In en, this message translates to:
  /// **'Your account has been deleted.'**
  String get accountDeletedNotice;

  /// No description provided for @inactivityReminderTitle1.
  ///
  /// In en, this message translates to:
  /// **'Ready for your next workout?'**
  String get inactivityReminderTitle1;

  /// No description provided for @inactivityReminderBody1.
  ///
  /// In en, this message translates to:
  /// **'Your training plan is waiting whenever you are. Even a short session counts.'**
  String get inactivityReminderBody1;

  /// No description provided for @inactivityReminderTitle2.
  ///
  /// In en, this message translates to:
  /// **'Small steps add up'**
  String get inactivityReminderTitle2;

  /// No description provided for @inactivityReminderBody2.
  ///
  /// In en, this message translates to:
  /// **'A few sets today keep your progress moving. Start whenever it suits you.'**
  String get inactivityReminderBody2;

  /// No description provided for @inactivityReminderTitle3.
  ///
  /// In en, this message translates to:
  /// **'Your workout is one tap away'**
  String get inactivityReminderTitle3;

  /// No description provided for @inactivityReminderBody3.
  ///
  /// In en, this message translates to:
  /// **'Pick up where you left off. Your programs are ready for you.'**
  String get inactivityReminderBody3;

  /// No description provided for @inactivityReminderTitle4.
  ///
  /// In en, this message translates to:
  /// **'Let\'s get moving again'**
  String get inactivityReminderTitle4;

  /// No description provided for @inactivityReminderBody4.
  ///
  /// In en, this message translates to:
  /// **'Consistency beats perfection. A quick session is a great restart.'**
  String get inactivityReminderBody4;

  /// No description provided for @inactivityReminderTitle5.
  ///
  /// In en, this message translates to:
  /// **'We saved your spot'**
  String get inactivityReminderTitle5;

  /// No description provided for @inactivityReminderBody5.
  ///
  /// In en, this message translates to:
  /// **'Your workouts are right where you left them. Come back anytime.'**
  String get inactivityReminderBody5;

  /// No description provided for @inactivityReminderTitle6.
  ///
  /// In en, this message translates to:
  /// **'Time for a fresh start?'**
  String get inactivityReminderTitle6;

  /// No description provided for @inactivityReminderBody6.
  ///
  /// In en, this message translates to:
  /// **'Every session is a new beginning. Open AE Coaching and start yours.'**
  String get inactivityReminderBody6;

  /// No description provided for @deleteAccountIncomplete.
  ///
  /// In en, this message translates to:
  /// **'An earlier deletion didn\'t finish. Enter your password to complete it.'**
  String get deleteAccountIncomplete;

  /// No description provided for @deleteAccountIncompleteNotice.
  ///
  /// In en, this message translates to:
  /// **'Your account deletion didn\'t finish. Until you complete it in Settings → Delete account, new changes are saved on this phone only.'**
  String get deleteAccountIncompleteNotice;

  /// No description provided for @progressViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get progressViewAll;

  /// No description provided for @progressAllTimeCaption.
  ///
  /// In en, this message translates to:
  /// **'Since you started'**
  String get progressAllTimeCaption;

  /// No description provided for @progressSinceCaption.
  ///
  /// In en, this message translates to:
  /// **'Since {date}'**
  String progressSinceCaption(String date);

  /// No description provided for @progressMetricSemantics.
  ///
  /// In en, this message translates to:
  /// **'{label}: {value}, {caption}'**
  String progressMetricSemantics(String label, int value, String caption);

  /// No description provided for @progressLatestRecords.
  ///
  /// In en, this message translates to:
  /// **'Latest personal records'**
  String get progressLatestRecords;

  /// No description provided for @progressRecentWorkoutsSection.
  ///
  /// In en, this message translates to:
  /// **'Recent workouts'**
  String get progressRecentWorkoutsSection;

  /// No description provided for @progressRangeDays.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get progressRangeDays;

  /// No description provided for @progressRangeWeeks.
  ///
  /// In en, this message translates to:
  /// **'6 weeks'**
  String get progressRangeWeeks;

  /// No description provided for @progressDailyChartSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Completed workouts per day over the last 7 days'**
  String get progressDailyChartSubtitle;

  /// No description provided for @progressWeeklyChartSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Completed workouts per week (Monday to Sunday) over the last 6 weeks'**
  String get progressWeeklyChartSubtitle;

  /// No description provided for @progressChartInfo.
  ///
  /// In en, this message translates to:
  /// **'A workout counts when you finish it with at least one logged set. Cancelled workouts don\'t count.'**
  String get progressChartInfo;

  /// No description provided for @progressChartTotal.
  ///
  /// In en, this message translates to:
  /// **'Total: {count}'**
  String progressChartTotal(int count);

  /// No description provided for @progressChartBarSemantics.
  ///
  /// In en, this message translates to:
  /// **'{period}: {count, plural, =1{1 completed workout} other{{count} completed workouts}}'**
  String progressChartBarSemantics(String period, int count);

  /// No description provided for @progressWeekOf.
  ///
  /// In en, this message translates to:
  /// **'Week of {date}'**
  String progressWeekOf(String date);

  /// No description provided for @progressTodayLabel.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get progressTodayLabel;

  /// No description provided for @progressWorkoutCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 workout} other{{count} workouts}}'**
  String progressWorkoutCount(int count);

  /// No description provided for @progressExerciseCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 exercise} other{{count} exercises}}'**
  String progressExerciseCount(int count);

  /// No description provided for @progressRecordsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your personal records will appear here once you log sets with weight.'**
  String get progressRecordsEmpty;

  /// No description provided for @progressRecordsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by exercise name'**
  String get progressRecordsSearchHint;

  /// No description provided for @progressRecordsNoResults.
  ///
  /// In en, this message translates to:
  /// **'No exercise matches “{query}”.'**
  String progressRecordsNoResults(String query);

  /// No description provided for @progressBestSetVolumeLabel.
  ///
  /// In en, this message translates to:
  /// **'Best single set (weight × reps)'**
  String get progressBestSetVolumeLabel;

  /// No description provided for @progressRecordSetOn.
  ///
  /// In en, this message translates to:
  /// **'Set on {date}'**
  String progressRecordSetOn(String date);

  /// No description provided for @progressAllPrograms.
  ///
  /// In en, this message translates to:
  /// **'All programs'**
  String get progressAllPrograms;

  /// No description provided for @progressFilterByProgram.
  ///
  /// In en, this message translates to:
  /// **'Filter by program'**
  String get progressFilterByProgram;

  /// No description provided for @progressHistoryNoResults.
  ///
  /// In en, this message translates to:
  /// **'No completed workouts in this program yet.'**
  String get progressHistoryNoResults;

  /// No description provided for @progressClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get progressClearSearch;

  /// No description provided for @progressWeightTimesReps.
  ///
  /// In en, this message translates to:
  /// **'{weight} kg × {reps}'**
  String progressWeightTimesReps(String weight, int reps);

  /// No description provided for @progressSetVolumeFormula.
  ///
  /// In en, this message translates to:
  /// **'{weight} kg × {reps} = {volume} kg'**
  String progressSetVolumeFormula(String weight, int reps, String volume);

  /// No description provided for @syncReviewNeeded.
  ///
  /// In en, this message translates to:
  /// **'Needs your review'**
  String get syncReviewNeeded;

  /// No description provided for @syncReviewAction.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get syncReviewAction;

  /// No description provided for @syncEditedElsewhereTitle.
  ///
  /// In en, this message translates to:
  /// **'Changed on another device'**
  String get syncEditedElsewhereTitle;

  /// No description provided for @syncEditedElsewhereBody.
  ///
  /// In en, this message translates to:
  /// **'This day was changed here and on another device. Choose the version to keep — the other one stays saved on this phone.'**
  String get syncEditedElsewhereBody;

  /// No description provided for @syncDeletedElsewhereTitle.
  ///
  /// In en, this message translates to:
  /// **'Deleted on another device'**
  String get syncDeletedElsewhereTitle;

  /// No description provided for @syncDeletedElsewhereBody.
  ///
  /// In en, this message translates to:
  /// **'This day was deleted on another device, but you changed it here. Restore it everywhere, or delete it here too.'**
  String get syncDeletedElsewhereBody;

  /// No description provided for @syncDeletedHereTitle.
  ///
  /// In en, this message translates to:
  /// **'Changed on another device after you deleted it'**
  String get syncDeletedHereTitle;

  /// No description provided for @syncDeletedHereBody.
  ///
  /// In en, this message translates to:
  /// **'You deleted this day, but it was changed on another device meanwhile. Delete it anyway, or keep it.'**
  String get syncDeletedHereBody;

  /// No description provided for @syncDiffersTitle.
  ///
  /// In en, this message translates to:
  /// **'Two different versions'**
  String get syncDiffersTitle;

  /// No description provided for @syncDiffersBody.
  ///
  /// In en, this message translates to:
  /// **'The version on this phone differs from the one saved in your account. Choose the version to keep — the other one stays saved on this phone.'**
  String get syncDiffersBody;

  /// No description provided for @syncOlderBuildTitle.
  ///
  /// In en, this message translates to:
  /// **'Replaced by an older app version'**
  String get syncOlderBuildTitle;

  /// No description provided for @syncOlderBuildBody.
  ///
  /// In en, this message translates to:
  /// **'An older version of the app replaced this day in your account. Choose the version to keep.'**
  String get syncOlderBuildBody;

  /// No description provided for @syncKeepMine.
  ///
  /// In en, this message translates to:
  /// **'Keep this phone\'s version'**
  String get syncKeepMine;

  /// No description provided for @syncKeepCloud.
  ///
  /// In en, this message translates to:
  /// **'Keep the other version'**
  String get syncKeepCloud;

  /// No description provided for @syncRestoreDay.
  ///
  /// In en, this message translates to:
  /// **'Restore the day'**
  String get syncRestoreDay;

  /// No description provided for @syncDeleteHereToo.
  ///
  /// In en, this message translates to:
  /// **'Delete it here too'**
  String get syncDeleteHereToo;

  /// No description provided for @syncDeleteAnyway.
  ///
  /// In en, this message translates to:
  /// **'Delete anyway'**
  String get syncDeleteAnyway;

  /// No description provided for @syncKeepDay.
  ///
  /// In en, this message translates to:
  /// **'Keep the day'**
  String get syncKeepDay;

  /// No description provided for @syncThisPhone.
  ///
  /// In en, this message translates to:
  /// **'This phone'**
  String get syncThisPhone;

  /// No description provided for @syncOtherVersion.
  ///
  /// In en, this message translates to:
  /// **'Other version'**
  String get syncOtherVersion;

  /// No description provided for @syncResolved.
  ///
  /// In en, this message translates to:
  /// **'Saved. The other version stays on this phone.'**
  String get syncResolved;

  /// No description provided for @syncLegacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Earlier exercises found'**
  String get syncLegacyTitle;

  /// No description provided for @syncLegacyBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 exercise was} other{{count} exercises were}} saved earlier for this day. Restore {count, plural, =1{it} other{them}}?'**
  String syncLegacyBody(int count);

  /// No description provided for @syncLegacySavedOn.
  ///
  /// In en, this message translates to:
  /// **'Saved on {date}'**
  String syncLegacySavedOn(String date);

  /// No description provided for @syncLegacyRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get syncLegacyRestore;

  /// No description provided for @syncLegacyDismiss.
  ///
  /// In en, this message translates to:
  /// **'Don\'t restore'**
  String get syncLegacyDismiss;

  /// No description provided for @syncLegacyRestored.
  ///
  /// In en, this message translates to:
  /// **'Exercises restored.'**
  String get syncLegacyRestored;

  /// No description provided for @syncEarlierVersionAvailable.
  ///
  /// In en, this message translates to:
  /// **'An earlier version of this day is available'**
  String get syncEarlierVersionAvailable;

  /// No description provided for @syncActivitiesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No activities} =1{1 activity} other{{count} activities}}'**
  String syncActivitiesCount(int count);

  /// No description provided for @activityLimitReached.
  ///
  /// In en, this message translates to:
  /// **'A workout day can hold up to {limit} activities.'**
  String activityLimitReached(int limit);

  /// No description provided for @syncLegacySplitNotice.
  ///
  /// In en, this message translates to:
  /// **'A day holds up to {limit} activities. The first {limit} are restored here and the other {remaining} go into {newDays, plural, =1{a new day} other{{newDays} new days}} at the end of this program.'**
  String syncLegacySplitNotice(int limit, int remaining, int newDays);

  /// No description provided for @syncNewDayLabel.
  ///
  /// In en, this message translates to:
  /// **'New day: {name}'**
  String syncNewDayLabel(String name);

  /// No description provided for @syncLegacyRestoredSplit.
  ///
  /// In en, this message translates to:
  /// **'Exercises restored into {days} days.'**
  String syncLegacyRestoredSplit(int days);

  /// No description provided for @syncTooManyTitle.
  ///
  /// In en, this message translates to:
  /// **'Too many activities to sync'**
  String get syncTooManyTitle;

  /// No description provided for @syncTooManyBody.
  ///
  /// In en, this message translates to:
  /// **'This day has {count} activities, more than the {limit} a day can sync. Until it is split, its changes stay on this phone only.'**
  String syncTooManyBody(int count, int limit);

  /// No description provided for @syncSplitDay.
  ///
  /// In en, this message translates to:
  /// **'Split day'**
  String get syncSplitDay;

  /// No description provided for @syncSplitConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Split this day?'**
  String get syncSplitConfirmTitle;

  /// No description provided for @syncSplitConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Activities after the first {limit} move, in the same order, to {newDays, plural, =1{a new day} other{{newDays} new days}} at the end of this program. Nothing is deleted.'**
  String syncSplitConfirmBody(int limit, int newDays);

  /// No description provided for @syncSplitDone.
  ///
  /// In en, this message translates to:
  /// **'Split into {days} days.'**
  String syncSplitDone(int days);

  /// No description provided for @addActivityButton.
  ///
  /// In en, this message translates to:
  /// **'Add activity'**
  String get addActivityButton;

  /// No description provided for @addActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Add activity'**
  String get addActivityTitle;

  /// No description provided for @addActivityStrengthTitle.
  ///
  /// In en, this message translates to:
  /// **'Strength exercise'**
  String get addActivityStrengthTitle;

  /// No description provided for @addActivityStrengthBody.
  ///
  /// In en, this message translates to:
  /// **'Sets and reps from the exercise library'**
  String get addActivityStrengthBody;

  /// No description provided for @addActivityCardioTitle.
  ///
  /// In en, this message translates to:
  /// **'Cardio'**
  String get addActivityCardioTitle;

  /// No description provided for @addActivityCardioBody.
  ///
  /// In en, this message translates to:
  /// **'Treadmill, bike, running and more'**
  String get addActivityCardioBody;

  /// No description provided for @addActivityLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'My library'**
  String get addActivityLibraryTitle;

  /// No description provided for @addActivityLibraryBody.
  ///
  /// In en, this message translates to:
  /// **'Exercises and activities you created'**
  String get addActivityLibraryBody;

  /// No description provided for @cardioLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Cardio library'**
  String get cardioLibraryTitle;

  /// No description provided for @cardioSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search cardio'**
  String get cardioSearchHint;

  /// No description provided for @cardioCategoryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get cardioCategoryAll;

  /// No description provided for @cardioCategoryMachines.
  ///
  /// In en, this message translates to:
  /// **'Machines & equipment'**
  String get cardioCategoryMachines;

  /// No description provided for @cardioCategoryBodyweight.
  ///
  /// In en, this message translates to:
  /// **'Bodyweight'**
  String get cardioCategoryBodyweight;

  /// No description provided for @cardioCategoryOutdoor.
  ///
  /// In en, this message translates to:
  /// **'Outdoor'**
  String get cardioCategoryOutdoor;

  /// No description provided for @cardioCategoryMine.
  ///
  /// In en, this message translates to:
  /// **'My cardio'**
  String get cardioCategoryMine;

  /// No description provided for @cardioNoResults.
  ///
  /// In en, this message translates to:
  /// **'No cardio activity matches your search.'**
  String get cardioNoResults;

  /// No description provided for @cardioMineEmpty.
  ///
  /// In en, this message translates to:
  /// **'Cardio activities you create appear here.'**
  String get cardioMineEmpty;

  /// No description provided for @cardioCreateCustom.
  ///
  /// In en, this message translates to:
  /// **'Create a cardio activity'**
  String get cardioCreateCustom;

  /// No description provided for @cardioCustomNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Activity name'**
  String get cardioCustomNameLabel;

  /// No description provided for @cardioCreateAndAdd.
  ///
  /// In en, this message translates to:
  /// **'Create and add'**
  String get cardioCreateAndAdd;

  /// No description provided for @cardioAlreadyInDay.
  ///
  /// In en, this message translates to:
  /// **'In this day'**
  String get cardioAlreadyInDay;

  /// No description provided for @cardioAddAction.
  ///
  /// In en, this message translates to:
  /// **'Add {name}'**
  String cardioAddAction(String name);

  /// No description provided for @cardioAddedToDay.
  ///
  /// In en, this message translates to:
  /// **'{name} added · {duration}'**
  String cardioAddedToDay(String name, String duration);

  /// No description provided for @cardioDurationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{1 min} other{{minutes} min}}'**
  String cardioDurationMinutes(int minutes);

  /// No description provided for @cardioModeCountdown.
  ///
  /// In en, this message translates to:
  /// **'Countdown'**
  String get cardioModeCountdown;

  /// No description provided for @cardioModeStopwatch.
  ///
  /// In en, this message translates to:
  /// **'Stopwatch'**
  String get cardioModeStopwatch;

  /// No description provided for @cardioModeIntervals.
  ///
  /// In en, this message translates to:
  /// **'Intervals'**
  String get cardioModeIntervals;

  /// No description provided for @cardioPlanSummary.
  ///
  /// In en, this message translates to:
  /// **'{mode} · {duration}'**
  String cardioPlanSummary(String mode, String duration);

  /// No description provided for @cardioShadowBoxing.
  ///
  /// In en, this message translates to:
  /// **'Shadow Boxing'**
  String get cardioShadowBoxing;

  /// No description provided for @cardioHiking.
  ///
  /// In en, this message translates to:
  /// **'Hiking'**
  String get cardioHiking;

  /// No description provided for @cardioSwimming.
  ///
  /// In en, this message translates to:
  /// **'Swimming'**
  String get cardioSwimming;

  /// No description provided for @cardioAirBikeAlsoKnown.
  ///
  /// In en, this message translates to:
  /// **'Also known as Assault Bike'**
  String get cardioAirBikeAlsoKnown;

  /// No description provided for @activityTypeCardio.
  ///
  /// In en, this message translates to:
  /// **'Cardio'**
  String get activityTypeCardio;

  /// No description provided for @myLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'My library'**
  String get myLibraryTitle;

  /// No description provided for @myLibraryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Exercises and cardio activities you create appear here.'**
  String get myLibraryEmpty;

  /// No description provided for @myLibraryStrengthSection.
  ///
  /// In en, this message translates to:
  /// **'Strength exercises'**
  String get myLibraryStrengthSection;

  /// No description provided for @myLibraryCardioSection.
  ///
  /// In en, this message translates to:
  /// **'Cardio'**
  String get myLibraryCardioSection;

  /// No description provided for @cardioSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Cardio settings'**
  String get cardioSettingsTitle;

  /// No description provided for @cardioTimerModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Timer mode'**
  String get cardioTimerModeLabel;

  /// No description provided for @cardioDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get cardioDurationLabel;

  /// No description provided for @cardioTargetToggle.
  ///
  /// In en, this message translates to:
  /// **'Set a target duration'**
  String get cardioTargetToggle;

  /// No description provided for @cardioWorkLabel.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get cardioWorkLabel;

  /// No description provided for @cardioIntervalRestLabel.
  ///
  /// In en, this message translates to:
  /// **'Rest'**
  String get cardioIntervalRestLabel;

  /// No description provided for @cardioRoundsLabel.
  ///
  /// In en, this message translates to:
  /// **'Rounds'**
  String get cardioRoundsLabel;

  /// No description provided for @cardioWarmupLabel.
  ///
  /// In en, this message translates to:
  /// **'Warm-up'**
  String get cardioWarmupLabel;

  /// No description provided for @cardioCooldownLabel.
  ///
  /// In en, this message translates to:
  /// **'Cool-down'**
  String get cardioCooldownLabel;

  /// No description provided for @cardioIntensityLabel.
  ///
  /// In en, this message translates to:
  /// **'Intensity (optional)'**
  String get cardioIntensityLabel;

  /// No description provided for @cardioIntensityLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get cardioIntensityLight;

  /// No description provided for @cardioIntensityModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get cardioIntensityModerate;

  /// No description provided for @cardioIntensityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get cardioIntensityHigh;

  /// No description provided for @cardioIntensityLightHint.
  ///
  /// In en, this message translates to:
  /// **'Effort (RPE) 2–4 of 10 · you can talk in full sentences.'**
  String get cardioIntensityLightHint;

  /// No description provided for @cardioIntensityModerateHint.
  ///
  /// In en, this message translates to:
  /// **'Effort (RPE) 5–6 of 10 · you can talk, but not sing.'**
  String get cardioIntensityModerateHint;

  /// No description provided for @cardioIntensityHighHint.
  ///
  /// In en, this message translates to:
  /// **'Effort (RPE) 7–8 of 10 · only a few words at a time.'**
  String get cardioIntensityHighHint;

  /// No description provided for @cardioDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Details (optional)'**
  String get cardioDetailsLabel;

  /// No description provided for @cardioSpeedLabel.
  ///
  /// In en, this message translates to:
  /// **'Speed (km/h)'**
  String get cardioSpeedLabel;

  /// No description provided for @cardioInclineLabel.
  ///
  /// In en, this message translates to:
  /// **'Incline (%)'**
  String get cardioInclineLabel;

  /// No description provided for @cardioResistanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Resistance level'**
  String get cardioResistanceLabel;

  /// No description provided for @cardioDistanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Distance (km)'**
  String get cardioDistanceLabel;

  /// No description provided for @cardioValueRange.
  ///
  /// In en, this message translates to:
  /// **'Between {min} and {max}'**
  String cardioValueRange(String min, String max);

  /// No description provided for @cardioPlannedTotal.
  ///
  /// In en, this message translates to:
  /// **'Planned: {duration}'**
  String cardioPlannedTotal(String duration);

  /// No description provided for @cardioSecondsValue.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String cardioSecondsValue(int seconds);

  /// No description provided for @cardioNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get cardioNone;

  /// No description provided for @cardioSettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Cardio settings saved.'**
  String get cardioSettingsSaved;

  /// No description provided for @cardioDecrease.
  ///
  /// In en, this message translates to:
  /// **'Decrease {label}'**
  String cardioDecrease(String label);

  /// No description provided for @cardioIncrease.
  ///
  /// In en, this message translates to:
  /// **'Increase {label}'**
  String cardioIncrease(String label);

  /// No description provided for @estimatedDuration.
  ///
  /// In en, this message translates to:
  /// **'Estimated: {duration}'**
  String estimatedDuration(String duration);

  /// No description provided for @estimatedDurationAtLeast.
  ///
  /// In en, this message translates to:
  /// **'Estimated: at least {duration}'**
  String estimatedDurationAtLeast(String duration);

  /// No description provided for @estimatedDurationNote.
  ///
  /// In en, this message translates to:
  /// **'An estimate from the planned sets, reps, rest and cardio time, not the time a workout took.'**
  String get estimatedDurationNote;

  /// No description provided for @undoAction.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undoAction;

  /// No description provided for @activityRemoved.
  ///
  /// In en, this message translates to:
  /// **'{name} removed'**
  String activityRemoved(String name);

  /// No description provided for @cardioJustAddedHint.
  ///
  /// In en, this message translates to:
  /// **'Added to the day with these settings. Save to change them, or Cancel to keep them.'**
  String get cardioJustAddedHint;

  /// No description provided for @cardioTimerStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get cardioTimerStart;

  /// No description provided for @cardioTimerPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get cardioTimerPause;

  /// No description provided for @cardioTimerResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get cardioTimerResume;

  /// No description provided for @cardioTimerFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get cardioTimerFinish;

  /// No description provided for @cardioTimerSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get cardioTimerSkip;

  /// No description provided for @cardioTimerOpen.
  ///
  /// In en, this message translates to:
  /// **'Open timer'**
  String get cardioTimerOpen;

  /// No description provided for @cardioTimerView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get cardioTimerView;

  /// No description provided for @cardioTimerStartAgain.
  ///
  /// In en, this message translates to:
  /// **'Do it anyway'**
  String get cardioTimerStartAgain;

  /// No description provided for @cardioRemainingLabel.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get cardioRemainingLabel;

  /// No description provided for @cardioElapsedLabel.
  ///
  /// In en, this message translates to:
  /// **'Elapsed'**
  String get cardioElapsedLabel;

  /// No description provided for @cardioPlannedValue.
  ///
  /// In en, this message translates to:
  /// **'Planned: {duration}'**
  String cardioPlannedValue(String duration);

  /// No description provided for @cardioTargetValue.
  ///
  /// In en, this message translates to:
  /// **'Target: {duration}'**
  String cardioTargetValue(String duration);

  /// No description provided for @cardioNoTarget.
  ///
  /// In en, this message translates to:
  /// **'No target: finish when you are done'**
  String get cardioNoTarget;

  /// No description provided for @cardioNextActivity.
  ///
  /// In en, this message translates to:
  /// **'Next: {name}'**
  String cardioNextActivity(String name);

  /// No description provided for @cardioLastActivity.
  ///
  /// In en, this message translates to:
  /// **'Last activity of this workout'**
  String get cardioLastActivity;

  /// No description provided for @cardioStatusNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get cardioStatusNotStarted;

  /// No description provided for @cardioStatusRunning.
  ///
  /// In en, this message translates to:
  /// **'In progress · {time}'**
  String cardioStatusRunning(String time);

  /// No description provided for @cardioStatusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused · {time}'**
  String cardioStatusPaused(String time);

  /// No description provided for @cardioStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Done · {time}'**
  String cardioStatusCompleted(String time);

  /// No description provided for @cardioStatusEndedEarly.
  ///
  /// In en, this message translates to:
  /// **'Ended early · {time}'**
  String cardioStatusEndedEarly(String time);

  /// No description provided for @cardioStatusSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get cardioStatusSkipped;

  /// No description provided for @intervalPhaseWarmup.
  ///
  /// In en, this message translates to:
  /// **'Warm-up'**
  String get intervalPhaseWarmup;

  /// No description provided for @intervalPhaseWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get intervalPhaseWork;

  /// No description provided for @intervalPhaseRest.
  ///
  /// In en, this message translates to:
  /// **'Rest'**
  String get intervalPhaseRest;

  /// No description provided for @intervalPhaseCooldown.
  ///
  /// In en, this message translates to:
  /// **'Cool-down'**
  String get intervalPhaseCooldown;

  /// No description provided for @intervalRoundOf.
  ///
  /// In en, this message translates to:
  /// **'Round {current} of {total}'**
  String intervalRoundOf(int current, int total);

  /// No description provided for @intervalNextPhase.
  ///
  /// In en, this message translates to:
  /// **'Next: {phase} · {duration}'**
  String intervalNextPhase(String phase, String duration);

  /// No description provided for @intervalLastPhase.
  ///
  /// In en, this message translates to:
  /// **'Last phase'**
  String get intervalLastPhase;

  /// No description provided for @cardioSkipConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Skip {name}?'**
  String cardioSkipConfirmTitle(String name);

  /// No description provided for @cardioSkipConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'It will be saved as skipped, not as done.'**
  String get cardioSkipConfirmBody;

  /// No description provided for @cardioFinishEarlyTitle.
  ///
  /// In en, this message translates to:
  /// **'Finish now?'**
  String get cardioFinishEarlyTitle;

  /// No description provided for @cardioFinishEarlyBody.
  ///
  /// In en, this message translates to:
  /// **'{actual} of {planned} done. It will be saved as ended early.'**
  String cardioFinishEarlyBody(String actual, String planned);

  /// No description provided for @cardioSoundOn.
  ///
  /// In en, this message translates to:
  /// **'Sounds and vibration on'**
  String get cardioSoundOn;

  /// No description provided for @cardioSoundOff.
  ///
  /// In en, this message translates to:
  /// **'Sounds and vibration off'**
  String get cardioSoundOff;

  /// No description provided for @cardioTargetReached.
  ///
  /// In en, this message translates to:
  /// **'Target reached. Keep going or finish.'**
  String get cardioTargetReached;

  /// No description provided for @cardioDoneMessage.
  ///
  /// In en, this message translates to:
  /// **'{name} done: {time}'**
  String cardioDoneMessage(String name, String time);

  /// No description provided for @cardioSkippedMessage.
  ///
  /// In en, this message translates to:
  /// **'{name} skipped'**
  String cardioSkippedMessage(String name);

  /// No description provided for @cardioBackgroundNote.
  ///
  /// In en, this message translates to:
  /// **'The timer keeps counting if you leave the app or lock the phone. Sounds play only while this screen is open.'**
  String get cardioBackgroundNote;

  /// No description provided for @cardioTimerSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save the timer. Try again.'**
  String get cardioTimerSaveError;

  /// No description provided for @cardioTimerProgress.
  ///
  /// In en, this message translates to:
  /// **'Timer progress'**
  String get cardioTimerProgress;

  /// No description provided for @finishWorkoutConfirmCardioBody.
  ///
  /// In en, this message translates to:
  /// **'Your cardio will be saved with this workout in your history.'**
  String get finishWorkoutConfirmCardioBody;

  /// No description provided for @completionCardioTitle.
  ///
  /// In en, this message translates to:
  /// **'Cardio'**
  String get completionCardioTitle;

  /// No description provided for @cardioBackToWorkout.
  ///
  /// In en, this message translates to:
  /// **'Back to workout'**
  String get cardioBackToWorkout;
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
