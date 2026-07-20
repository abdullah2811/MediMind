import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/models/medication.dart';

class MedicationNotificationService {
  MedicationNotificationService() : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestExactAlarmsPermission();
    _initialized = true;
  }

  Future<void> scheduleMedication(Medication medication) async {
    await initialize();
    await cancelMedicationById(medication.id);

    final doseTimes = medication.doseTimes.isNotEmpty
        ? medication.doseTimes
        : <String>[medication.timeOfDay];

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'medimind_reminders',
        'Medicine reminders',
        channelDescription: 'Medicine reminder alerts for MediMind',
        category: AndroidNotificationCategory.alarm,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        fullScreenIntent: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
    );

    for (var i = 0; i < doseTimes.length; i++) {
      final reminderTime = _parseTimeOfDay(doseTimes[i]);
      final notificationId = _notificationId(medication.id, i);
      final nextTrigger = _nextInstanceOf(reminderTime);

      await _plugin.zonedSchedule(
        notificationId,
        medication.medicineName,
        _notificationBody(medication, doseTimes[i]),
        nextTrigger,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }

    if (medication.mealScheduleEnabled) {
      final mealTimes = medication.mealTimes.isNotEmpty
          ? medication.mealTimes
          : doseTimes
                .map((time) => calculateMealTime(time, medication.mealOffset))
                .toList(growable: false);
      for (var i = 0; i < mealTimes.length; i++) {
        final mealTime = _parseTimeOfDay(mealTimes[i]);
        await _plugin.zonedSchedule(
          _notificationId(medication.id, 12 + i),
          medication.languageCode == 'bn' ? 'খাবারের সময়' : 'Meal time',
          medication.languageCode == 'bn'
              ? '${medication.medicineName}-এর সঙ্গে মিলিয়ে এখন খাবারের সময়।'
              : 'Your meal linked to ${medication.medicineName} is scheduled now.',
          _nextInstanceOf(mealTime),
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    }
  }

  Future<void> cancelMedication(Medication medication) async {
    await initialize();
    await cancelMedicationById(medication.id);
  }

  Future<void> cancelMedicationById(
    String medicationId, {
    int possibleDoseCount = 24,
  }) async {
    await initialize();
    for (var i = 0; i < possibleDoseCount; i++) {
      await _plugin.cancel(_notificationId(medicationId, i));
    }
  }

  Future<void> rescheduleAll(List<Medication> medications) async {
    await initialize();
    await _plugin.cancelAll();
    for (final medication in medications) {
      await scheduleMedication(medication);
    }
  }

  String _notificationBody(Medication medication, String timeLabel) {
    MedicationDose? matchingDose;
    for (final dose in medication.effectiveDoses) {
      if (dose.timeOfDay == timeLabel) {
        matchingDose = dose;
        break;
      }
    }
    if (medication.languageCode == 'bn') {
      final dosage = matchingDose == null || matchingDose.dosageValue.isEmpty
          ? ''
          : ' • পরিমাণ: ${matchingDose.dosageValue} '
                '${_banglaDosageUnit(matchingDose.dosageUnit)}';
      return 'ওষুধ খাওয়ার সময়: $timeLabel$dosage';
    }
    final dosage = matchingDose == null || matchingDose.dosageValue.isEmpty
        ? ''
        : ' • Dosage: ${matchingDose.dosageValue} '
              '${matchingDose.dosageUnit}';
    return 'Medicine time: $timeLabel$dosage';
  }

  String _banglaDosageUnit(String unit) {
    return switch (unit) {
      'ml' => 'মি.লি.',
      'drop' => 'ফোঁটা',
      _ => 'টি',
    };
  }

  TimeOfDay _parseTimeOfDay(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      return TimeOfDay.now();
    }
    final hour = int.tryParse(parts[0]) ?? TimeOfDay.now().hour;
    final minute = int.tryParse(parts[1]) ?? TimeOfDay.now().minute;
    return TimeOfDay(hour: hour, minute: minute);
  }

  tz.TZDateTime _nextInstanceOf(TimeOfDay timeOfDay) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      timeOfDay.hour,
      timeOfDay.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  int _notificationId(String medicationId, int doseIndex) {
    return ('${medicationId}_$doseIndex').hashCode & 0x7fffffff;
  }
}
