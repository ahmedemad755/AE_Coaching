import 'package:ae_coaching/features/account_deletion/application/account_deletion_lifecycle.dart';
import 'package:ae_coaching/features/account_deletion/domain/account_deletion.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'account_deletion_state.dart';

class AccountDeletionCubit extends Cubit<AccountDeletionState> {
  AccountDeletionCubit({
    required AccountDeletionRepository repository,
    required AccountDeletionLifecycle lifecycle,
    required String? Function() currentUid,
    required Future<void> Function() onStarted,
  }) : _repository = repository,
       _lifecycle = lifecycle,
       _currentUid = currentUid,
       _onStarted = onStarted,
       super(const AccountDeletionState.loading());

  final AccountDeletionRepository _repository;
  final AccountDeletionLifecycle _lifecycle;
  final String? Function() _currentUid;

  /// Runs once deletion starts (e.g. cancel local reminders).
  final Future<void> Function() _onStarted;

  Future<void> load() async {
    emit(const AccountDeletionState.loading());
    final uid = _currentUid();
    if (uid == null) {
      emit(const AccountDeletionState.unavailable());
      return;
    }
    try {
      if (await _lifecycle.finalizeIfCompleted() == DeletionCompletion.accountDeleted) {
        if (!isClosed) emit(const AccountDeletionState.accountDeleted());
        return;
      }
    } catch (_) {
      // Cleanup is retried at the next app start.
    }
    if (!isClosed) emit(AccountDeletionState.ready(incomplete: _lifecycle.isInProgress(uid)));
  }

  /// Re-authenticates, deletes the account's data and then the account,
  /// then this device's data. Reports [AccountDeletionOutcome.deleted] only
  /// when Firebase confirmed every step.
  Future<AccountDeletionOutcome> deleteAccount(String password) async {
    if (state.submitting) return AccountDeletionOutcome.busy;
    if (state.status != AccountDeletionStatus.ready) return AccountDeletionOutcome.failed;
    final uid = _currentUid();
    if (uid == null) return AccountDeletionOutcome.failed;
    emit(state.copyWith(submitting: true));
    try {
      await _repository.reauthenticate(password);
      if (_currentUid() != uid) return AccountDeletionOutcome.failed;
      await _lifecycle.markStarted(uid);
      try {
        await _onStarted();
      } catch (_) {}
      await _repository.deleteAccount(uid);
      try {
        await _lifecycle.completeLocally(uid);
      } catch (_) {
        // The account is deleted; leftover device data is removed at the
        // next app start (the marker is kept).
      }
      if (!isClosed) emit(const AccountDeletionState.accountDeleted());
      return AccountDeletionOutcome.deleted;
    } on AccountDeletionException catch (error) {
      if (!isClosed) emit(state.copyWith(incomplete: _lifecycle.isInProgress(uid)));
      return switch (error.failure) {
        AccountDeletionFailure.wrongPassword => AccountDeletionOutcome.wrongPassword,
        AccountDeletionFailure.tooManyAttempts => AccountDeletionOutcome.tooManyAttempts,
        AccountDeletionFailure.offline => AccountDeletionOutcome.offline,
        AccountDeletionFailure.recentSignInRequired => AccountDeletionOutcome.recentSignInRequired,
        AccountDeletionFailure.unsupportedSignIn => AccountDeletionOutcome.unsupportedSignIn,
        _ => AccountDeletionOutcome.failed,
      };
    } catch (_) {
      if (!isClosed) emit(state.copyWith(incomplete: _lifecycle.isInProgress(uid)));
      return AccountDeletionOutcome.failed;
    } finally {
      if (!isClosed && state.submitting) emit(state.copyWith(submitting: false));
    }
  }
}
