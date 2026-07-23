package com.example.medimind

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

object ReminderWakeScheduler {
    private const val PREFERENCES = "medimind_wake_alarms"
    private const val IDS = "ids"
    private const val ACTION_PREFIX = "com.example.medimind.WAKE_REMINDER."

    fun replace(context: Context, reminders: List<*>) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        val previousIds = preferences.getStringSet(IDS, emptySet()).orEmpty()
        for (storedId in previousIds) {
            storedId.toIntOrNull()?.let { id ->
                alarmManager.cancel(pendingIntent(context, id))
            }
        }

        val scheduledIds = mutableSetOf<String>()
        for (rawReminder in reminders) {
            val reminder = rawReminder as? Map<*, *> ?: continue
            val id = (reminder["id"] as? Number)?.toInt() ?: continue
            val scheduledAt =
                (reminder["scheduledAtMilliseconds"] as? Number)?.toLong() ?: continue
            if (scheduledAt <= System.currentTimeMillis()) {
                continue
            }
            schedule(alarmManager, scheduledAt, pendingIntent(context, id))
            scheduledIds.add(id.toString())
        }
        preferences.edit().putStringSet(IDS, scheduledIds).apply()
    }

    private fun schedule(
        alarmManager: AlarmManager,
        scheduledAt: Long,
        operation: PendingIntent,
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            !alarmManager.canScheduleExactAlarms()
        ) {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                scheduledAt,
                operation,
            )
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                scheduledAt,
                operation,
            )
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, scheduledAt, operation)
        }
    }

    private fun pendingIntent(context: Context, id: Int): PendingIntent {
        val intent = Intent(context, ReminderWakeReceiver::class.java).apply {
            action = "$ACTION_PREFIX$id"
        }
        return PendingIntent.getBroadcast(
            context,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
