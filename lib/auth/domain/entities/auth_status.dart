/// The single, authoritative answer to "what may this user do right
/// now?". It is derived from the Firebase Auth identity and the
/// `users/{uid}` profile, never from a persisted route or a local flag
/// alone.
///
/// Transitions (email-first, see docs/architecture.md
/// "Authentication lifecycle"):
///
/// ```
///   unauthenticated ──(register)───────────────────▶ pendingEmailVerification
///   unauthenticated ──(login, email not verified)──▶ pendingEmailVerification
///   pendingEmailVerification ──(link opened + refresh)──▶ authenticated
///                                 └─(profile missing, no name)──▶ incompleteProfile
///   incompleteProfile ──(name saved)───────────────▶ authenticated
///   (any profile read/write failure) ──────────────▶ profileUnavailable ─(Retry)─▶ re-resolved
///   any ──(sign out)───────────────────────────────▶ unauthenticated
///   phone-era test account ────────────────────────▶ unsupportedLegacyAccount ─(signed out)─▶ unauthenticated
/// ```
///
/// Verification gating in the app is a UX and navigation control. It is
/// NOT authorization: a modified client could skip it. The server-side
/// guarantee comes from Firestore rules that check
/// `request.auth.token.email_verified` (Stage 3D).
enum AuthStatus {
  /// No Firebase identity. Only Login/Register/Forgot Password are reachable.
  unauthenticated,

  /// Fully verified identity with a profile. Protected access allowed.
  authenticated,

  /// Email/password account whose email isn't verified yet. Only the
  /// Verify Email screen is reachable (resend, refresh, change email,
  /// sign out).
  pendingEmailVerification,

  /// Verified identity whose `users/{uid}` profile is missing (sign-up
  /// interrupted) and whose name can't be recovered automatically.
  incompleteProfile,

  /// A phone-era test account (synthetic `@ae-coaching.app` email). Left
  /// untouched in Firebase (Stage 3A decision A) but no longer usable:
  /// the session is signed out. Nothing is deleted.
  unsupportedLegacyAccount,

  /// Verified identity whose profile could not be confirmed: the read or
  /// repair failed (offline, permission denied) or the document is
  /// conflicting. NO protected access. The user gets Retry / Sign out,
  /// with the actual reason.
  profileUnavailable,
}
