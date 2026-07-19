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
    final reminderTime = _parseTimeOfDay(medication.timeOfDay);
    final notificationId = _notificationId(medication.id);
    final nextTrigger = _nextInstanceOf(reminderTime);

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'medimind_reminders',
        'Medicine reminders',
        channelDescription: 'Medicine reminder alerts for MediMind',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
    );

    await _plugin.zonedSchedule(
      notificationId,
      medication.medicineName,
      _notificationBody(medication),
      nextTrigger,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelMedication(String medicationId) async {
    await initialize();
    await _plugin.cancel(_notificationId(medicationId));
  }

  Future<void> rescheduleAll(List<Medication> medications) async {
    await initialize();
    await _plugin.cancelAll();
    for (final medication in medications) {
      if (medication.isActive) {
        await scheduleMedication(medication);
      }
    }
  }

  String _notificationBody(Medication medication) {
    final parts = <String>[
      if (medication.dose.isNotEmpty) 'Dose: ${medication.dose}',
      if (medication.durationDays > 0)
        'Duration: ${medication.durationDays} days',
    ];
    return parts.isEmpty ? 'Time to take your medicine.' : parts.join(' • ');
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

  int _notificationId(String medicationId) {
    return medicationId.hashCode & 0x7fffffff;
  }
}
