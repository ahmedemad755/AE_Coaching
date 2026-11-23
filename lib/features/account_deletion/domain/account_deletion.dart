/// In-app account deletion (Firebase Spark plan, no Cloud Functions).
///
/// After re-authentication the app deletes every Firestore document it
/// stores for the account (each subcollection, then the profile), and only
/// then the Firebase Auth account, so an interruption never leaves data
/// without an owner who can still delete it. Every step is idempotent: an
/// interrupted deletion is completed by running it again.
library;

enum AccountDeletionFailure {
  wrongPassword,
  tooManyAttempts,

  /// No connection: nothing is started, or the deletion stopped part-way
  /// and must be finished online.
  offline,

  /// The sign-in is not recent enough (Firebase and the rules require it).
  recentSignInRequired,
  notSignedIn,

  /// The account has no password to re-authenticate with.
  unsupportedSignIn,
  unknown,
}

class AccountDeletionException implements Exception {
  const AccountDeletionException(this.failure);

  final AccountDeletionFailure failure;

  @override
  String toString() => 'AccountDeletionException(${failure.name})';
}

/// Everything account deletion needs from Firebase.
abstract interface class AccountDeletionRepository {
  /// Confirms the user's identity with their password (Email/Password is
  /// the app's only sign-in method). Throws [AccountDeletionException].
  Future<void> reauthenticate(String password);

  /// Deletes the account's Firestore data, then its Auth account (last).
  /// Throws [AccountDeletionException]; safe to call again after a failure.
  Future<void> deleteAccount(String uid);

  /// `true` while the signed-in account exists, `false` once Firebase
  /// reports it deleted, `null` when that can't be determined (offline).
  Future<bool?> accountStillExists();
}
