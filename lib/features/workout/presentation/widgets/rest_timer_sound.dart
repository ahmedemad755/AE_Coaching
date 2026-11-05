import 'package:flutter/services.dart';

class RestTimerSound {
  static const MethodChannel _channel = MethodChannel('ae_coaching/rest_timer');

  static Future<void> play() async {
    try {
      await _channel.invokeMethod<void>('playNotificationSound');
    } on MissingPluginException {
      // Non-Android platforms may not implement the app's native sound channel.
    } on PlatformException {
      // Sound output is best-effort and must not interrupt the workout.
    }
  }
}
