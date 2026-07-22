import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/models/medication.dart';
import '../../domain/services/medication_image_data.dart';
import 'medication_notification_action_handler.dart';

class MedicationReminderPlanItem {
  MedicationReminderPlanItem({required this.scheduledAt});

  final DateTime scheduledAt;
  final List<({Medication medication, MedicationDose dose})> doses = [];
  final List<({Medication medication, MedicationDose dose})> meals = [];

  bool get hasMedicine => doses.isNotEmpty;
  bool get hasMeal => meals.isNotEmpty;
}

List<MedicationReminderPlanItem> buildMedicationReminderPlan(
  List<Medication> medications, {
  DateTime? from,
  int horizonDays = 365,
  int maxEvents = 360,
}) {
  final now = from ?? DateTime.now();
  final firstDay = DateTime(now.year, now.month, now.day);
  final events = <int, MedicationReminderPlanItem>{};

  MedicationReminderPlanItem eventAt(DateTime time) {
    final minuteKey =
        time.millisecondsSinceEpoch ~/ Duration.millisecondsPerMinute;
    return events.putIfAbsent(
      minuteKey,
      () => MedicationReminderPlanItem(scheduledAt: time),
    );
  }

  for (final medication in medications.where((item) => item.isActive)) {
    for (var dayOffset = 0; dayOffset <= horizonDays; dayOffset++) {
      final day = firstDay.add(Duration(days: dayOffset));
      if (!medication.occursOnDate(day)) {
        continue;
      }
      for (final dose in medication.effectiveDoses) {
        if (dose.timeOfDay.isEmpty) {
          continue;
        }
        final doseTime = _dateAtClockTime(day, dose.timeOfDay);
        if (doseTime.isAfter(now)) {
          eventAt(doseTime).doses.add((medication: medication, dose: dose));
        }

        if (medication.mealScheduleEnabled) {
          final mealTime = doseTime.subtract(
            Duration(minutes: medication.mealOffset),
          );
          if (mealTime.isAfter(now)) {
            final mealEvent = eventAt(mealTime);
            if (!mealEvent.meals.any(
              (item) =>
                  item.medication.id == medication.id &&
                  item.dose.timeOfDay == dose.timeOfDay,
            )) {
              mealEvent.meals.add((medication: medication, dose: dose));
            }
          }
        }
      }
    }
  }

  final plan = events.values.toList(growable: false)
    ..sort((left, right) => left.scheduledAt.compareTo(right.scheduledAt));
  return plan.take(maxEvents).toList(growable: false);
}

String _canonicalClockTime(String value) {
  final parts = value.split(':');
  final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  return '${hour.clamp(0, 23).toString().padLeft(2, '0')}:'
      '${minute.clamp(0, 59).toString().padLeft(2, '0')}';
}

DateTime _dateAtClockTime(DateTime date, String time) {
  final canonical = _canonicalClockTime(time).split(':');
  return DateTime(
    date.year,
    date.month,
    date.day,
    int.parse(canonical[0]),
    int.parse(canonical[1]),
  );
}

class MedicationNotificationService {
  MedicationNotificationService() : _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'medimind_critical_reminders_v2';
  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  bool _canScheduleExact = true;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_medimind'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        defaultPresentAlert: true,
        defaultPresentBadge: true,
        defaultPresentSound: true,
      ),
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: medicationNotificationActionBackground,
      onDidReceiveBackgroundNotificationResponse:
          medicationNotificationActionBackground,
    );
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
    await android?.requestFullScreenIntentPermission();
    _canScheduleExact = await android?.canScheduleExactNotifications() ?? true;

    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    _initialized = true;
  }

  Future<void> scheduleMedication(Medication medication, {String uid = ''}) {
    return rescheduleAll(<Medication>[medication], uid: uid);
  }

  Future<void> rescheduleAll(
    List<Medication> medications, {
    String uid = '',
  }) async {
    if (kIsWeb) {
      return;
    }
    await initialize();
    await _plugin.cancelAll();

    final maxEvents = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
        ? 60
        : 360;
    for (final event in buildMedicationReminderPlan(
      medications,
      maxEvents: maxEvents,
    )) {
      final trigger = tz.TZDateTime.from(event.scheduledAt, tz.local);
      final content = _notificationContent(event);
      final details = _notificationDetails(
        content.title,
        content.body,
        event,
        isBangla: content.isBangla,
      );
      await _plugin.zonedSchedule(
        _notificationId(event.scheduledAt),
        content.title,
        content.body,
        trigger,
        details,
        payload: _notificationPayload(event, uid: uid),
        androidScheduleMode: _canScheduleExact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelMedication(Medication medication) async {
    if (kIsWeb) {
      return;
    }
    await initialize();
    await _plugin.cancelAll();
  }

  Future<void> cancelMedicationById(String medicationId) async {
    if (kIsWeb) {
      return;
    }
    await initialize();
    await _plugin.cancelAll();
  }

  NotificationDetails _notificationDetails(
    String title,
    String body,
    MedicationReminderPlanItem event, {
    required bool isBangla,
  }) {
    final eventMedications = <String, Medication>{
      for (final item in event.doses) item.medication.id: item.medication,
      for (final item in event.meals) item.medication.id: item.medication,
    };
    Uint8List? artworkBytes;
    for (final medication in eventMedications.values) {
      artworkBytes = medicationImageBytes(medication);
      if (artworkBytes != null) {
        break;
      }
    }
    final artwork = artworkBytes == null
        ? null
        : ByteArrayAndroidBitmap(artworkBytes);
    final StyleInformation styleInformation;
    if (artwork != null && eventMedications.length == 1) {
      styleInformation = BigPictureStyleInformation(
        artwork,
        contentTitle: title,
        summaryText: body,
        largeIcon: artwork,
        hideExpandedLargeIcon: true,
      );
    } else {
      styleInformation = BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'MediMind',
      );
    }
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'MediMind alarms and reminders',
        channelDescription:
            'High-priority medicine and meal reminders from MediMind',
        icon: 'ic_stat_medimind',
        color: const Color(0xFF552746),
        ledColor: const Color(0xFFE36B4F),
        enableLights: true,
        ledOnMs: 1000,
        ledOffMs: 500,
        category: AndroidNotificationCategory.alarm,
        importance: Importance.max,
        priority: Priority.max,
        visibility: NotificationVisibility.public,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList(<int>[0, 500, 220, 500, 220, 800]),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        fullScreenIntent: true,
        groupKey: 'medimind_daily_reminders',
        ticker: 'MediMind reminder',
        subText: 'MediMind',
        largeIcon: artwork,
        styleInformation: styleInformation,
        actions: _notificationActions(event, isBangla: isBangla),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentList: true,
        presentSound: true,
        presentBadge: true,
        threadIdentifier: 'medimind_daily_reminders',
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }

  ({String title, String body, bool isBangla}) _notificationContent(
    MedicationReminderPlanItem event,
  ) {
    final isBangla = <Medication>[
      ...event.doses.map((item) => item.medication),
      ...event.meals.map((item) => item.medication),
    ].every((item) => item.languageCode == 'bn');
    final time = _format12Hour(
      '${event.scheduledAt.hour.toString().padLeft(2, '0')}:'
      '${event.scheduledAt.minute.toString().padLeft(2, '0')}',
    );
    final doseText = event.doses
        .map((item) {
          final value = item.dose.dosageValue.trim();
          final unit = isBangla
              ? _banglaDosageUnit(item.dose.dosageUnit)
              : _englishDosageUnit(item.dose.dosageUnit);
          return value.isEmpty
              ? item.medication.medicineName
              : '${item.medication.medicineName} — $value $unit';
        })
        .join(' • ');
    final mealNames = event.meals
        .map((item) => item.medication.medicineName)
        .toSet()
        .join(', ');

    if (isBangla) {
      final title = event.hasMedicine && event.hasMeal
          ? 'MediMind • ওষুধ ও খাবারের সময়'
          : event.hasMedicine
          ? 'MediMind • ওষুধের সময়'
          : 'MediMind • খাবারের সময়';
      final parts = <String>[
        if (event.hasMedicine) doseText,
        if (event.hasMeal) '$mealNames-এর সঙ্গে নির্ধারিত খাবার',
        'সময় $time',
      ];
      return (title: title, body: parts.join(' • '), isBangla: true);
    }

    final title = event.hasMedicine && event.hasMeal
        ? 'MediMind • Medicine and meal'
        : event.hasMedicine
        ? 'MediMind • Medicine time'
        : 'MediMind • Meal time';
    final parts = <String>[
      if (event.hasMedicine) doseText,
      if (event.hasMeal) 'Meal linked to $mealNames',
      'Due at $time',
    ];
    return (title: title, body: parts.join(' • '), isBangla: false);
  }

  List<AndroidNotificationAction> _notificationActions(
    MedicationReminderPlanItem event, {
    required bool isBangla,
  }) {
    if (event.hasMedicine && event.hasMeal) {
      return <AndroidNotificationAction>[
        AndroidNotificationAction(
          allTakenAction,
          isBangla ? 'সব নেওয়া হয়েছে' : 'All taken',
          showsUserInterface: false,
        ),
        AndroidNotificationAction(
          allNotTakenAction,
          isBangla ? 'কোনোটিই নেওয়া হয়নি' : 'None taken',
          showsUserInterface: false,
        ),
      ];
    }
    if (event.hasMedicine) {
      return <AndroidNotificationAction>[
        AndroidNotificationAction(
          medicineTakenAction,
          isBangla ? 'ওষুধ নিয়েছি' : 'Medicine taken',
          showsUserInterface: false,
        ),
        AndroidNotificationAction(
          medicineNotTakenAction,
          isBangla ? 'ওষুধ নিইনি' : 'Not taken',
          showsUserInterface: false,
        ),
      ];
    }
    return <AndroidNotificationAction>[
      AndroidNotificationAction(
        mealTakenAction,
        isBangla ? 'খাবার খেয়েছি' : 'Meal taken',
        showsUserInterface: false,
      ),
      AndroidNotificationAction(
        mealNotTakenAction,
        isBangla ? 'খাবার খাইনি' : 'Meal not taken',
        showsUserInterface: false,
      ),
    ];
  }

  String _notificationPayload(
    MedicationReminderPlanItem event, {
    required String uid,
  }) {
    Map<String, String> occurrence(
      Medication medication,
      MedicationDose dose,
      DateTime date,
    ) {
      return <String, String>{
        'medicationId': medication.id,
        'dateKey': medicationDateKey(date),
        'doseTime': dose.timeOfDay,
      };
    }

    return jsonEncode(<String, dynamic>{
      'uid': uid,
      'scheduledAt': event.scheduledAt.toIso8601String(),
      'doses': event.doses
          .map(
            (item) => occurrence(item.medication, item.dose, event.scheduledAt),
          )
          .toList(growable: false),
      'meals': event.meals
          .map(
            (item) => occurrence(
              item.medication,
              item.dose,
              event.scheduledAt.add(
                Duration(minutes: item.medication.mealOffset),
              ),
            ),
          )
          .toList(growable: false),
    });
  }

  String _englishDosageUnit(String unit) {
    return switch (unit) {
      'ml' => 'ml',
      'drop' => 'drop(s)',
      'unit' => 'Units',
      _ => 'pill(s)',
    };
  }

  String _banglaDosageUnit(String unit) {
    return switch (unit) {
      'ml' => 'মি.লি.',
      'drop' => 'ফোঁটা',
      'unit' => 'ইউনিট',
      _ => 'টি',
    };
  }

  String _format12Hour(String time) {
    final parsed = _parseTimeOfDay(time);
    final hour = parsed.hourOfPeriod == 0 ? 12 : parsed.hourOfPeriod;
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${parsed.period == DayPeriod.am ? 'AM' : 'PM'}';
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

  int _notificationId(DateTime scheduledAt) {
    return (scheduledAt.millisecondsSinceEpoch ~/
            Duration.millisecondsPerMinute) &
        0x7fffffff;
  }
}
