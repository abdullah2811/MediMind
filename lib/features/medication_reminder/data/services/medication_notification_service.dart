import 'dart:async';
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

  bool get hasMedicine => doses.isNotEmpty;
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

  // Android notification-channel settings are immutable after the channel is
  // created. A new id ensures existing installs receive the corrected alarm
  // importance, sound, vibration, and lock-screen visibility settings.
  static const _channelId = 'medimind_critical_reminders_v5';
  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<String> _openedReminderController =
      StreamController<String>.broadcast();
  bool _initialized = false;
  bool _canScheduleExact = true;
  Future<void>? _initializing;
  String? _pendingOpenedReminderPayload;

  Stream<String> get openedReminderPayloads => _openedReminderController.stream;

  String? takePendingOpenedReminderPayload() {
    final payload = _pendingOpenedReminderPayload;
    _pendingOpenedReminderPayload = null;
    return payload;
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    final initializing = _initializing;
    if (initializing != null) {
      return initializing;
    }
    final operation = _initialize();
    _initializing = operation;
    try {
      await operation;
    } finally {
      _initializing = null;
    }
  }

  Future<void> _initialize() async {
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
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          medicationNotificationActionBackground,
    );
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final launchResponse = launchDetails?.notificationResponse;
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchResponse != null) {
      await _handleNotificationResponse(launchResponse);
    }
    // Mark the plugin ready before asking for optional Android access. A
    // rejected permission must not leave notification initialization broken.
    _initialized = true;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await _requestPermission(
      'notifications',
      () => android?.requestNotificationsPermission(),
    );
    await _requestPermission(
      'exact alarms',
      () => android?.requestExactAlarmsPermission(),
    );
    await _refreshExactAlarmCapability(android);

    await _requestPermission(
      'iOS notifications',
      () => _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true),
    );
  }

  Future<void> _handleNotificationResponse(
    NotificationResponse response,
  ) async {
    final actionId = response.actionId;
    if (actionId != null && actionId.isNotEmpty) {
      await medicationNotificationActionBackground(response);
      return;
    }
    final payload = response.payload;
    if (payload == null || payload.isEmpty) {
      return;
    }
    _pendingOpenedReminderPayload = payload;
    _openedReminderController.add(payload);
  }

  Future<void> _requestPermission(
    String name,
    Future<bool?>? Function() request,
  ) async {
    try {
      await request();
    } catch (error, stackTrace) {
      debugPrint('Could not request $name permission: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _refreshExactAlarmCapability(
    AndroidFlutterLocalNotificationsPlugin? android,
  ) async {
    try {
      _canScheduleExact =
          await android?.canScheduleExactNotifications() ?? true;
    } catch (error) {
      _canScheduleExact = false;
      debugPrint('Could not check exact-alarm access: $error');
    }
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
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await _refreshExactAlarmCapability(android);
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
        _notificationId(event),
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
        channelDescription: 'High-priority medicine reminders from MediMind',
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
        fullScreenIntent: false,
        groupKey: 'medimind_medicine_reminders',
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
        threadIdentifier: 'medimind_reminders',
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }

  ({String title, String body, String message, bool isBangla})
  _notificationContent(MedicationReminderPlanItem event) {
    final isBangla = event.doses.every(
      (item) => item.medication.languageCode == 'bn',
    );
    final time = _format12Hour(
      '${event.scheduledAt.hour.toString().padLeft(2, '0')}:'
      '${event.scheduledAt.minute.toString().padLeft(2, '0')}',
    );
    final doseLines = event.doses
        .map((item) {
          final value = item.dose.dosageValue.trim();
          final unit = isBangla
              ? _banglaDosageUnit(item.dose.dosageUnit)
              : _englishDosageUnit(item.dose.dosageUnit);
          return value.isEmpty
              ? item.medication.medicineName
              : '${item.medication.medicineName} — $value $unit';
        })
        .toList(growable: false);

    if (isBangla) {
      const title = 'রিমাইন্ডার: ওষুধ';
      const message = 'তথ্য লিখুন এবং আপনার ওষুধ নিন।';
      final parts = <String>[
        message,
        ...doseLines.map((line) => '• $line'),
        'সময় $time',
      ];
      return (
        title: title,
        body: parts.join('\n'),
        message: message,
        isBangla: true,
      );
    }

    const title = 'Reminder: Medicine';
    const message = 'Log your data and take your medicine.';
    final parts = <String>[
      message,
      ...doseLines.map((line) => '• $line'),
      'Due at $time',
    ];
    return (
      title: title,
      body: parts.join('\n'),
      message: message,
      isBangla: false,
    );
  }

  List<AndroidNotificationAction> _notificationActions(
    MedicationReminderPlanItem event, {
    required bool isBangla,
  }) {
    final hasMultipleMedicines = event.doses.length > 1;
    return <AndroidNotificationAction>[
      AndroidNotificationAction(
        medicineTakenAction,
        isBangla
            ? hasMultipleMedicines
                  ? 'সব ওষুধ নিয়েছি'
                  : 'ওষুধ নিয়েছি'
            : hasMultipleMedicines
            ? 'All taken'
            : 'Medicine taken',
        showsUserInterface: false,
      ),
      AndroidNotificationAction(
        medicineNotTakenAction,
        isBangla
            ? hasMultipleMedicines
                  ? 'কোনো ওষুধ নিইনি'
                  : 'ওষুধ নিইনি'
            : hasMultipleMedicines
            ? 'None taken'
            : 'Not taken',
        showsUserInterface: false,
      ),
    ];
  }

  String _notificationPayload(
    MedicationReminderPlanItem event, {
    required String uid,
  }) {
    final content = _notificationContent(event);
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
      'alarmCard': true,
      'eventType': 'medicine',
      'displayTitle': content.title,
      'displayBody': content.body,
      'displayMessage': content.message,
      'isBangla': content.isBangla,
      'medicineItems': event.doses
          .map(
            (item) => <String, String>{
              'name': item.medication.medicineName,
              'dosage': _notificationDosage(item.dose, content.isBangla),
            },
          )
          .toList(growable: false),
      'doses': event.doses
          .map(
            (item) => occurrence(item.medication, item.dose, event.scheduledAt),
          )
          .toList(growable: false),
    });
  }

  String _notificationDosage(MedicationDose dose, bool isBangla) {
    final value = dose.dosageValue.trim();
    if (value.isEmpty) {
      return '';
    }
    final unit = isBangla
        ? _banglaDosageUnit(dose.dosageUnit)
        : _englishDosageUnit(dose.dosageUnit);
    return '$value $unit';
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

  int _notificationId(MedicationReminderPlanItem event) {
    return (event.scheduledAt.millisecondsSinceEpoch ~/
            Duration.millisecondsPerMinute) &
        0x7fffffff;
  }
}
