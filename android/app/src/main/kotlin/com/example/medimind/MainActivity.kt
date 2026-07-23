package com.example.medimind

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WAKE_SCREEN_CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (call.method != "replaceWakeAlarms") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val reminders = call.arguments as? List<*> ?: emptyList<Any>()
            ReminderWakeScheduler.replace(applicationContext, reminders)
            result.success(null)
        }
    }

    companion object {
        private const val WAKE_SCREEN_CHANNEL = "medimind/wake_screen"
    }
}
