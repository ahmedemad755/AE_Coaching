import 'dart:async';

import 'package:flutter/foundation.dart';

/// Client-side resend cooldown for verification emails. This is UX only,
/// not a security control: Firebase Auth enforces its own server-side
/// quota (`too-many-requests`). The cooldown stops users from burning
/// through that quota by tapping Resend repeatedly.
class ResendCooldown extends ChangeNotifier {
  static const Duration defaultDuration = Duration(seconds: 60);

  final Duration duration;
  Timer? _timer;
  int _remainingSeconds = 0;

  ResendCooldown({this.duration = defaultDuration});

  int get remainingSeconds => _remainingSeconds;
  bool get isActive => _remainingSeconds > 0;

  void start() {
    _timer?.cancel();
    _remainingSeconds = duration.inSeconds;
    notifyListeners();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _remainingSeconds--;
      if (_remainingSeconds <= 0) {
        _remainingSeconds = 0;
        timer.cancel();
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
