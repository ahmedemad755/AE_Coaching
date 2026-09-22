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
  String get completeRegistrationSetPasswordTitle => 'Set a password';

  @override
  String completeRegistrationSetPasswordSubtitle(String phone) {
    return 'Your phone number $phone is verified. Choose a password to secure your account.';
  }

  @override
  String get completeRegistrationFinishProfileTitle => 'Finish your profile';

  @override
  String get completeRegistrationFinishProfileSubtitle =>
      'Just need your name to finish setting up your account.';

  @override
  String get completeRegistrationCancelAndSignOut =>
      'This isn\'t me — start over';

  @override
  String get sessionCheckingMessage => 'Checking your account...';

  @override
  String get verifyPhoneMigrationTitle => 'Verify your phone';

  @override
  String verifyPhoneMigrationSubtitle(String phone) {
    return 'For your account\'s security, confirm the code sent to $phone.';
  }

  @override
  String get phoneVerifiedSuccessMessage => 'Phone verified successfully';

  @override
  String get forgotPasswordTitle => 'Reset your password';

  @override
  String get forgotPasswordSubtitle =>
      'Enter your phone number and we\'ll send you a verification code.';

  @override
  String get sendCodeButton => 'SEND CODE';

  @override
  String get resetPasswordTitle => 'Enter new password';

  @override
  String resetPasswordSubtitle(String phone) {
    return 'Enter the code sent to $phone and choose a new password.';
  }

  @override
  String get confirmPasswordHint => 'Confirm password';

  @override
  String get confirmPasswordRequired => 'Please confirm your password';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get resetPasswordButton => 'RESET PASSWORD';

  @override
  String get passwordChangedSuccessMessage => 'Password changed successfully';

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

  @override
  String get myProgramsTitle => 'My Programs';

  @override
  String get activeProgramLabel => 'Active Program';

  @override
  String get previousProgramsLabel => 'Previous Programs';

  @override
  String get createProgramButton => 'Create Program';

  @override
  String get createProgramTitle => 'Create Program';

  @override
  String get programNameHint => 'Program Name';

  @override
  String get descriptionOptionalHint => 'Description (optional)';

  @override
  String get createButton => 'Create';

  @override
  String get createAndMakeActiveButton => 'Create & Make Active';

  @override
  String get makeActiveButton => 'Make Active';

  @override
  String get renameButton => 'Rename';

  @override
  String get renameProgramTitle => 'Rename Program';

  @override
  String get archiveButton => 'Archive';

  @override
  String get openButton => 'Open';

  @override
  String get noProgramsYetTitle => 'No programs yet.';

  @override
  String get noProgramsYetSubtitle =>
      'Create your first program to start organizing your training.';

  @override
  String get makeActiveConfirmTitle => 'Make Active?';

  @override
  String makeActiveConfirmBodyWithCurrent(String name) {
    return 'Make \"$name\" your active program? Your current program will remain saved as a previous program.';
  }

  @override
  String makeActiveConfirmBodyNoCurrent(String name) {
    return 'Make \"$name\" your active program?';
  }

  @override
  String get archiveActiveConfirmTitle => 'Archive Program?';

  @override
  String archiveActiveConfirmBody(String name) {
    return 'Archive \"$name\"? It will move to Previous Programs — your workout history stays intact.';
  }

  @override
  String get enterProgramNameValidation => 'Enter a program name.';

  @override
  String get unableToLoadProgramsError => 'Unable to load your programs.';

  @override
  String get workoutDaysPlaceholder =>
      'Workout Days will be added in the next phase.';

  @override
  String get startedLabel => 'Started';

  @override
  String get endedLabel => 'Ended';

  @override
  String get workoutProgramsTooltip => 'My Programs';

  @override
  String get workoutDaysTitle => 'Workout Days';

  @override
  String get addWorkoutDayButton => 'Add Workout Day';

  @override
  String get createWorkoutDayTitle => 'Add Workout Day';

  @override
  String get renameWorkoutDayTitle => 'Rename Workout Day';

  @override
  String get workoutDayNameHint => 'Workout Day Name';

  @override
  String get noWorkoutDaysYetTitle => 'No workout days yet.';

  @override
  String get noWorkoutDaysYetSubtitle =>
      'Add a workout day like \"Push 1\" to start building this program.';

  @override
  String get archiveWorkoutDayConfirmTitle => 'Archive Workout Day?';

  @override
  String archiveWorkoutDayConfirmBody(String name) {
    return 'Archive \"$name\"? It will be hidden from this list, but any workout history stays intact.';
  }

  @override
  String get enterWorkoutDayNameValidation => 'Enter a workout day name.';

  @override
  String get unableToLoadWorkoutDaysError => 'Unable to load workout days.';

  @override
  String get startWorkoutButton => 'Start Workout';

  @override
  String get moveUpTooltip => 'Move up';

  @override
  String get moveDownTooltip => 'Move down';

  @override
  String get startWorkoutComingSoon =>
      'Starting a workout is coming in the next phase.';

  @override
  String get resumeWorkoutBannerTitle => 'Workout in progress';

  @override
  String resumeWorkoutBannerBody(String name, String elapsed) {
    return '$name — started $elapsed ago';
  }

  @override
  String get resumeWorkoutButton => 'Resume Workout';

  @override
  String get workoutInProgressConflictTitle => 'Workout Already In Progress';

  @override
  String workoutInProgressConflictBody(String name) {
    return 'You already have \"$name\" in progress. Finish or cancel it before starting a new workout.';
  }

  @override
  String get cancelWorkoutButton => 'Cancel Workout';

  @override
  String get cancelWorkoutConfirmTitle => 'Cancel this workout?';

  @override
  String get cancelWorkoutConfirmBody =>
      'This workout session will be marked cancelled and won\'t count toward your history. This can\'t be undone.';

  @override
  String get finishWorkoutButton => 'Finish Workout';

  @override
  String get finishWorkoutComingSoon =>
      'Finishing a workout is coming in the next phase.';

  @override
  String get elapsedTimeLabel => 'Elapsed Time';

  @override
  String get unableToStartWorkoutError => 'Unable to start the workout.';

  @override
  String get sessionExercisesTitle => 'Exercises';

  @override
  String get noExercisesLoggedYetBody =>
      'No exercises logged yet. Tap \"New Exercise\" to add your first set.';

  @override
  String get suggestedFromLastTimeLabel => 'Suggested from last time';

  @override
  String get logFirstSetButton => 'Log Set';

  @override
  String get addSetTooltip => 'Add another set';

  @override
  String get deleteSetTooltip => 'Delete set';

  @override
  String get unableToLogSetError => 'Unable to log this set.';

  @override
  String get exerciseNameRequiredError => 'Please enter an exercise name.';

  @override
  String get lastTimeLabel => 'Last time';

  @override
  String get finishWorkoutConfirmTitle => 'Finish this workout?';

  @override
  String finishWorkoutConfirmBody(String volume) {
    return 'Total volume logged: $volume kg. This will mark the session complete and save it to your history.';
  }

  @override
  String workoutFinishedBody(String volume) {
    return 'Workout completed! Total volume: $volume kg.';
  }

  @override
  String get unableToFinishWorkoutError => 'Unable to finish the workout.';

  @override
  String get workoutSummaryTitle => 'Workout Summary';

  @override
  String get sessionTotalVolumeLabel => 'Total Volume';

  @override
  String get sinceLastTimeLabel => 'Since Last Time';

  @override
  String get noPreviousSessionBody =>
      'No previous session for this workout day yet — next time you\'ll see how you compare.';

  @override
  String get newPersonalRecordsLabel => 'New Personal Records';

  @override
  String firstTimePrBody(String exercise) {
    return 'First time logging $exercise!';
  }

  @override
  String heaviestWeightPrBody(String exercise, String weight, String previous) {
    return '$exercise: heaviest weight ever — $weight kg (was $previous kg)';
  }

  @override
  String highestSetVolumePrBody(String exercise, String weight, int reps) {
    return '$exercise: best single set ever — $weight kg × $reps';
  }

  @override
  String get exerciseImprovedLabel => 'Improved';

  @override
  String get exerciseMaintainedLabel => 'Maintained';

  @override
  String get exerciseDeclinedLabel => 'Declined';

  @override
  String get exerciseNewLabel => 'New';

  @override
  String get doneButton => 'Done';

  @override
  String workoutHistoryTitle(String name) {
    return '$name History';
  }

  @override
  String get historyTooltip => 'History';

  @override
  String get noSessionsYetTitle => 'No sessions yet';

  @override
  String get noSessionsYetSubtitle =>
      'Finish a workout for this day to start building its history.';

  @override
  String get sessionCompletedLabel => 'Completed';

  @override
  String get sessionCancelledLabel => 'Cancelled';

  @override
  String get sessionInProgressLabel => 'In Progress';

  @override
  String get sessionDurationLabel => 'Duration';

  @override
  String get viewWorkoutTrackerButton => 'View Workout Tracker';

  @override
  String get programAnalyticsTitle => 'Program Analytics';

  @override
  String get analyticsTooltip => 'Analytics';

  @override
  String get noAnalyticsYetTitle => 'No data yet';

  @override
  String get noAnalyticsYetSubtitle =>
      'Finish a few workouts to start seeing trends here.';

  @override
  String sessionsLoggedLabel(int count) {
    return '$count sessions';
  }

  @override
  String get averageVolumeLabel => 'Avg volume';

  @override
  String get bestWeightLabel => 'Best';

  @override
  String get noExercisesForDayYetBody =>
      'No completed sessions for this day yet.';

  @override
  String get thisWeekTitle => 'This Week';

  @override
  String totalSessionsThisWeekLabel(int count) {
    return '$count sessions completed';
  }

  @override
  String templateSessionsThisWeekLabel(int count) {
    return '$count×';
  }

  @override
  String get restTimerLabel => 'Rest Timer';

  @override
  String get startRestTimerButton => 'Start';

  @override
  String get stopRestTimerButton => 'Stop';

  @override
  String get resetRestTimerTooltip => 'Reset';

  @override
  String get setNotesHint => 'Notes (optional)';

  @override
  String get sessionNoteTooltip => 'Session Note';

  @override
  String get editSessionNoteTitle => 'Session Note';

  @override
  String get sessionNoteHint => 'How did this workout feel?';

  @override
  String get saveNoteButton => 'Save';

  @override
  String get unableToSaveNoteError => 'Unable to save the note.';

  @override
  String get consistencyTitle => 'Consistency';

  @override
  String get currentWeekStreakLabel => 'Current streak';

  @override
  String weeksUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'weeks',
      one: 'week',
    );
    return '$count $_temp0';
  }

  @override
  String get longestWeekStreakLabel => 'Longest streak';

  @override
  String get averagePerWeekLabel => 'Avg per week';

  @override
  String get daysSinceLastSessionLabel => 'Last workout';

  @override
  String daysAgoLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'days ago',
      one: 'day ago',
      zero: 'days ago',
    );
    return '$count $_temp0';
  }

  @override
  String get noConsistencyDataYetBody =>
      'Complete a few workouts to see your consistency here.';

  @override
  String get kgUnit => 'kg';

  @override
  String currentVsPreviousVolumeLabel(String current, String previous) {
    return '$current kg ($previous kg last time)';
  }

  @override
  String durationHoursMinutesLabel(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String durationMinutesOnlyLabel(int minutes) {
    return '${minutes}m';
  }

  @override
  String durationSecondsOnlyLabel(int seconds) {
    return '${seconds}s';
  }

  @override
  String exerciseBestLatestSummary(String bestWeight, String latestVolume) {
    return 'Best: $bestWeight kg  •  $latestVolume kg latest';
  }

  @override
  String get homeCurrentProgramLabel => 'Current Program';

  @override
  String homeWorkoutsCompletedThisWeekLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'workouts completed',
      one: 'workout completed',
      zero: 'workouts completed',
    );
    return '$count $_temp0';
  }

  @override
  String get homeOpenProgramButton => 'Open Program';

  @override
  String get homeWorkoutInProgressLabel => 'Workout in Progress';

  @override
  String homeStartedAgoLabel(String duration) {
    return 'Started $duration ago';
  }

  @override
  String get homeRecentWorkoutsTitle => 'Recent Workouts';

  @override
  String homeExerciseCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Exercises',
      one: 'Exercise',
    );
    return '$count $_temp0';
  }

  @override
  String homeSetCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sets',
      one: 'Set',
    );
    return '$count $_temp0';
  }

  @override
  String homeTotalVolumeLabel(String volume) {
    return 'Total Volume: $volume kg';
  }

  @override
  String get homeViewSessionButton => 'View Session';

  @override
  String get homeShowExercisesButton => 'Show exercises';

  @override
  String get homeHideExercisesButton => 'Hide exercises';

  @override
  String get homeNoActiveProgramTitle => 'No Active Program';

  @override
  String get homeNoActiveProgramBody =>
      'Create or activate a program to start tracking structured workouts.';

  @override
  String get homeNoRecentWorkoutsBody => 'No completed workouts yet.';

  @override
  String get startWorkoutFabLabel => 'Start Workout';

  @override
  String get deleteProgramConfirmTitle => 'Delete this program permanently?';

  @override
  String deleteProgramConfirmBody(String name) {
    return 'This will permanently delete \"$name\" and everything in it — every workout day, every session, every logged set. This cannot be undone.';
  }

  @override
  String get deleteWorkoutDayConfirmTitle =>
      'Delete this workout day permanently?';

  @override
  String deleteWorkoutDayConfirmBody(String name) {
    return 'This will permanently delete \"$name\" and everything in it — every session, every logged set. This cannot be undone.';
  }

  @override
  String get archivedWorkoutDaysTooltip => 'Archived';

  @override
  String get archivedWorkoutDaysTitle => 'Archived Workout Days';

  @override
  String get noArchivedWorkoutDaysBody => 'No archived workout days.';

  @override
  String get restoreButton => 'Restore';
}
