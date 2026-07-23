package com.example.medimind

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.PowerManager

class ReminderWakeReceiver : BroadcastReceiver() {
    @Suppress("DEPRECATION")
    override fun onReceive(context: Context, intent: Intent) {
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = powerManager.newWakeLock(
            PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE,
            "MediMind:MedicineReminder",
        )
        wakeLock.setReferenceCounted(false)
        wakeLock.acquire(WAKE_DURATION_MS)
    }

    companion object {
        private const val WAKE_DURATION_MS = 8_000L
    }
}
