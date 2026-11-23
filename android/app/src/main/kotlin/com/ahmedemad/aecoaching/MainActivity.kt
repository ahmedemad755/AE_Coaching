package com.ahmedemad.aecoaching

import android.media.AudioAttributes
import android.media.RingtoneManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ae_coaching/rest_timer",
        ).setMethodCallHandler { call, result ->
            if (call.method == "keepScreenOn") {
                // A running cardio timer keeps the screen on (Stage 6).
                if (call.arguments == true) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                }
                result.success(null)
                return@setMethodCallHandler
            }
            if (call.method != "playNotificationSound") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            try {
                playDefaultNotificationSound()
                result.success(null)
            } catch (error: RuntimeException) {
                result.error("notification_sound_error", error.message, null)
            }
        }
    }

    private fun playDefaultNotificationSound() {
        val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            ?: return
        val ringtone = RingtoneManager.getRingtone(applicationContext, soundUri)
            ?: return
        ringtone.audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        ringtone.play()
    }
}
