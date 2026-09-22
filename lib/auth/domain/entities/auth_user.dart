class AuthUser {
  final String uid;
  final String name;
  final String phoneNumber;

  /// True only for a password-authenticated legacy account that has no
  /// phone provider linked yet (Phase 4). Always false for Phase 3
  /// accounts, which always have both providers linked by the time an
  /// [AuthUser] is returned for them.
  final bool needsPhoneVerification;

  const AuthUser({
    required this.uid,
    required this.name,
    required this.phoneNumber,
    this.needsPhoneVerification = false,
  });
}
