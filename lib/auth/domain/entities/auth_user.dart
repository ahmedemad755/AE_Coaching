/// The signed-in, authenticated account as the app sees it. Built only
/// from a confirmed-valid profile (see `assessProfile`).
class AuthUser {
  final String uid;
  final String name;

  /// The account's sign-in email (Firebase Auth is authoritative).
  final String email;

  const AuthUser({required this.uid, required this.name, this.email = ''});
}
