import 'package:ae_coaching/auth/domain/validation/auth_input_rules.dart';
import 'package:ae_coaching/core/session/session_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Where the app may open, decided before the first frame.
enum StartupDestination {
  /// Verified session confirmed by Firebase Auth. Works offline.
  home,

  /// No Firebase identity.
  login,

  /// A Firebase identity exists, but local state can't prove it may
  /// enter: no or mismatched local marker, unverified email, or a
  /// phone-era test account. The authoritative check (server reload +
  /// `users/{uid}`) runs in SessionReconciliationView.
  sessionCheck,
}

/// The facts the startup and route decisions are made from. Every
/// Firebase field comes from Firebase Auth's own persisted user, which is
/// the source of truth and available offline. The local marker is only a
/// hint that a previous run finished setup. It is never enough on its
/// own.
class StartupAuthSnapshot {
  final String? firebaseUid;
  final String firebaseEmail;
  final bool firebaseEmailVerified;

  /// Email/Password accounts must verify. Federated providers (Google,
  /// Apple) arrive verified by the provider.
  final bool firebaseUsesPassword;
  final bool localSessionMarked;
  final String localSessionUid;

  const StartupAuthSnapshot({
    required this.firebaseUid,
    this.firebaseEmail = '',
    this.firebaseEmailVerified = false,
    this.firebaseUsesPassword = true,
    this.localSessionMarked = false,
    this.localSessionUid = '',
  });

  factory StartupAuthSnapshot.read({
    required FirebaseAuth auth,
    SessionStorage? sessionStorage,
  }) {
    final user = auth.currentUser;
    return StartupAuthSnapshot(
      firebaseUid: user?.uid,
      firebaseEmail: user?.email ?? '',
      firebaseEmailVerified: user?.emailVerified ?? false,
      firebaseUsesPassword:
          user?.providerData.any((p) => p.providerId == 'password') ?? false,
      localSessionMarked: sessionStorage?.isLoggedIn ?? false,
      localSessionUid: sessionStorage?.currentUserUid ?? '',
    );
  }

  bool get hasIdentity => (firebaseUid?.trim() ?? '').isNotEmpty;

  bool get isLegacyAccount => AuthInputRules.isReservedEmail(firebaseEmail);

  bool get requiresEmailVerification =>
      firebaseUsesPassword && !firebaseEmailVerified;

  /// Identity-level clearance: signed in, verified (when required), and
  /// not a phone-era account.
  bool get identityCleared =>
      hasIdentity && !isLegacyAccount && !requiresEmailVerification;
}

/// Pure startup policy, kept free of Flutter and Firebase so it can be
/// unit-tested exhaustively.
StartupDestination resolveStartupDestination(StartupAuthSnapshot s) {
  if (!s.hasIdentity) return StartupDestination.login;
  final uid = s.firebaseUid!.trim();
  final markerMatches = s.localSessionMarked && s.localSessionUid.trim() == uid;
  if (markerMatches && s.identityCleared) return StartupDestination.home;
  return StartupDestination.sessionCheck;
}

/// Route guard policy: may a protected (non-auth) route be built right
/// now?
///
/// This is CLIENT-SIDE gating. It stops navigation (a stray pushNamed,
/// deep link, or back-stack quirk) from reaching Home or feature screens
/// with an unverified account. It is not authorization: a modified
/// client can bypass anything on the device. Server-side enforcement is
/// Firestore rules checking `request.auth.token.email_verified`
/// (Stage 3D).
bool canEnterProtectedRoute(StartupAuthSnapshot s) => s.identityCleared;
