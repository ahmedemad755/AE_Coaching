import 'package:ae_coaching/auth/domain/validation/auth_input_rules.dart';

/// State of a `users/{uid}` document as far as entering the app is
/// concerned. Only [valid] may reach Home.
enum ProfileCondition {
  /// No document.
  missing,

  /// Usable: `uid` matches the account and `name` passes the name rule.
  valid,

  /// Exists but lacks required data (no/blank/invalid `name`, or no `uid`
  /// field). Only the MISSING fields may be filled in. Present valid data
  /// is never overwritten.
  repairable,

  /// Belongs to a different account (`uid` field mismatch). Never written
  /// to and never entered: the user is told to contact support.
  conflicting,
}

/// Pure, so the same rule decides in the data source, in the
/// Firestore transaction, and in tests.
ProfileCondition assessProfile(Map<String, dynamic>? data, String uid) {
  if (data == null) return ProfileCondition.missing;
  final docUid = data['uid'];
  if (docUid != null && docUid != uid) return ProfileCondition.conflicting;
  final name = data['name'];
  final nameValid = name is String && AuthInputRules.validateName(name) == null;
  if (docUid == null || !nameValid) return ProfileCondition.repairable;
  return ProfileCondition.valid;
}

/// Why a verified account's profile couldn't be confirmed.
enum ProfileFailure {
  /// Offline / Firestore unavailable. Retry is expected to work.
  network,

  /// Firestore rejected the read or write (`permission-denied`). Reported
  /// as such, never disguised as success or as a generic error.
  permissionDenied,

  /// The document belongs to another account. Retry won't help.
  conflicting,

  /// Anything else.
  unknown,
}
