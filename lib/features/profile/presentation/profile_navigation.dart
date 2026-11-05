typedef ProfileLogoutCallback = Future<void> Function();

class PersonalHubArgs {
  const PersonalHubArgs({required this.onLogout});
  final ProfileLogoutCallback onLogout;
}

class AppSettingsArgs {
  const AppSettingsArgs({required this.onLogout});
  final ProfileLogoutCallback onLogout;
}
