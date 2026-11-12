import 'dart:async';

import 'package:ae_coaching/features/notification_settings/data/device_time_zone.dart';
import 'package:ae_coaching/features/notification_settings/data/verified_account.dart';
import 'package:ae_coaching/features/notification_settings/domain/notification_preferences.dart';
import 'package:ae_coaching/features/notification_settings/domain/notification_preferences_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'notification_preferences_state.dart';

/// The workout reminder switch on the Settings screen, for ONE account:
/// the verified uid at [start] is the only one this cubit reads or writes.
class NotificationPreferencesCubit extends Cubit<NotificationPreferencesState> {
  NotificationPreferencesCubit({
    required NotificationPreferencesRepository repository,
    required DeviceTimeZone deviceTimeZone,
    required VerifiedAccount account,
    required String Function() languageCode,
  }) : _repository = repository,
       _deviceTimeZone = deviceTimeZone,
       _account = account,
       _languageCode = languageCode,
       super(const NotificationPreferencesState.loading());

  final NotificationPreferencesRepository _repository;
  final DeviceTimeZone _deviceTimeZone;
  final VerifiedAccount _account;
  final String Function() _languageCode;
  StreamSubscription<StoredNotificationPreferences>? _subscription;
  String? _uid;

  /// Starts (or, after a failure, restarts) watching the account's
  /// preference.
  Future<void> start() async {
    // Cancelling stops delivery at once; no need to wait for the
    // listener's teardown before listening again.
    unawaited(_subscription?.cancel());
    _subscription = null;
    _uid = _account.currentUid();
    final uid = _uid;
    if (uid == null) {
      emit(const NotificationPreferencesState.unavailable());
      return;
    }
    emit(const NotificationPreferencesState.loading());
    _subscription = _repository.watch(uid).listen(
      (stored) {
        if (isClosed) return;
        // Offline with nothing confirmed for this account: do not present
        // the default as if it were the user's choice.
        emit(
          !stored.exists && stored.isFromCache
              ? NotificationPreferencesState.offline(saving: state.saving)
              : NotificationPreferencesState.ready(stored, saving: state.saving),
        );
      },
      onError: (Object error) {
        if (isClosed) return;
        emit(
          NotificationPreferencesState.failure(
            error is NotificationPreferencesException ? error.failure : NotificationPreferencesFailure.unknown,
          ),
        );
      },
    );
  }

  Future<PreferenceSaveOutcome> setEnabled(bool enabled) async {
    final stored = state.stored;
    if (state.saving) return PreferenceSaveOutcome.busy;
    if (state.status != NotificationPreferencesStatus.ready || stored == null) {
      return PreferenceSaveOutcome.failed;
    }
    final uid = _uid;
    if (uid == null || _account.currentUid() != uid) return PreferenceSaveOutcome.accountChanged;

    emit(state.copyWith(saving: true));
    try {
      final desired = resolveDesiredPreferences(
        stored: stored,
        language: ReminderLanguage.fromLocaleCode(_languageCode()),
        deviceTimeZone: await _deviceTimeZone.current(),
        enabled: enabled,
      );
      if (_account.currentUid() != uid) return PreferenceSaveOutcome.accountChanged;
      return switch (await _repository.save(uid, desired)) {
        PreferenceSaveResult.confirmed => PreferenceSaveOutcome.confirmed,
        PreferenceSaveResult.pendingSync => PreferenceSaveOutcome.pendingSync,
      };
    } on NotificationPreferencesException catch (error) {
      return error.failure == NotificationPreferencesFailure.permissionDenied
          ? PreferenceSaveOutcome.rejected
          : PreferenceSaveOutcome.failed;
    } catch (_) {
      return PreferenceSaveOutcome.failed;
    } finally {
      if (!isClosed) emit(state.copyWith(saving: false));
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
