part of 'account_deletion_cubit.dart';

enum AccountDeletionStatus {
  loading,

  /// The form can be submitted ([incomplete]: finishing an interrupted one).
  ready,

  /// The account is deleted and this device's data removed.
  accountDeleted,
  unavailable,
}

/// What a submit achieved; only [deleted] means the account is gone.
enum AccountDeletionOutcome {
  deleted,
  wrongPassword,
  tooManyAttempts,
  offline,
  recentSignInRequired,
  unsupportedSignIn,
  failed,
  busy,
}

class AccountDeletionState {
  const AccountDeletionState._({required this.status, this.incomplete = false, this.submitting = false});

  const AccountDeletionState.loading() : this._(status: AccountDeletionStatus.loading);

  const AccountDeletionState.ready({bool incomplete = false})
    : this._(status: AccountDeletionStatus.ready, incomplete: incomplete);

  const AccountDeletionState.accountDeleted() : this._(status: AccountDeletionStatus.accountDeleted);

  const AccountDeletionState.unavailable() : this._(status: AccountDeletionStatus.unavailable);

  final AccountDeletionStatus status;

  /// An earlier deletion stopped part-way; submitting finishes it.
  final bool incomplete;
  final bool submitting;

  AccountDeletionState copyWith({bool? submitting, bool? incomplete}) => AccountDeletionState._(
    status: status,
    incomplete: incomplete ?? this.incomplete,
    submitting: submitting ?? this.submitting,
  );
}
