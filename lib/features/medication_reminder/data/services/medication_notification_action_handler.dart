import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/models/medication.dart';
import '../../domain/services/medication_report_builder.dart';
import '../datasources/medication_local_data_source.dart';
import '../datasources/medication_report_local_data_source.dart';

const medicineTakenAction = 'medicine_taken';
const medicineNotTakenAction = 'medicine_not_taken';
const mealTakenAction = 'meal_taken';
const mealNotTakenAction = 'meal_not_taken';
const allTakenAction = 'all_taken';
const allNotTakenAction = 'all_not_taken';

typedef ReminderOccurrence = ({String dateKey, String doseTime});

@pragma('vm:entry-point')
Future<void> medicationNotificationActionBackground(
  NotificationResponse response,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  final actionId = response.actionId;
  final payload = response.payload;
  if (actionId == null || actionId.isEmpty || payload == null) {
    return;
  }

  final payloadData = _decodeMap(payload);
  final uid = payloadData?['uid'] as String?;
  if (uid == null || uid.isEmpty) {
    return;
  }

  final directory = await _actionDirectory();
  final recordedAt = DateTime.now();
  final file = File(
    '${directory.path}${Platform.pathSeparator}'
    '${recordedAt.microsecondsSinceEpoch}_${response.id}.json',
  );
  await file.writeAsString(
    jsonEncode(<String, dynamic>{
      'actionId': actionId,
      'payload': payloadData,
      'recordedAt': recordedAt.toIso8601String(),
    }),
    flush: true,
  );
}

Future<bool> applyPendingMedicationNotificationActions({
  required String uid,
  required MedicationLocalDataSource localDataSource,
  required MedicationReportLocalDataSource reportLocalDataSource,
}) async {
  if (kIsWeb || uid.isEmpty) {
    return false;
  }
  final directory = await _actionDirectory();
  final files =
      directory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.json'))
          .toList(growable: false)
        ..sort((left, right) => left.path.compareTo(right.path));
  var changed = false;
  DateTime? latestActionTime;

  for (final file in files) {
    try {
      final envelope = _decodeMap(await file.readAsString());
      final payloadValue = envelope?['payload'];
      if (envelope == null || payloadValue is! Map) {
        await file.delete();
        continue;
      }
      final payload = Map<String, dynamic>.from(payloadValue);
      if (payload['uid'] != uid) {
        continue;
      }
      final actionId = envelope['actionId'] as String?;
      final recordedAt = DateTime.tryParse(
        envelope['recordedAt'] as String? ?? '',
      );
      if (actionId == null || recordedAt == null) {
        await file.delete();
        continue;
      }

      await _applyActionPayload(
        uid: uid,
        actionId: actionId,
        payload: payload,
        recordedAt: recordedAt,
        localDataSource: localDataSource,
      );
      await file.delete();
      changed = true;
      if (latestActionTime == null || recordedAt.isAfter(latestActionTime)) {
        latestActionTime = recordedAt;
      }
    } on FileSystemException {
      // Keep a file that could not be read or removed so the next app resume
      // can safely retry it.
    } on FormatException {
      await file.delete();
    }
  }

  if (!changed) {
    return false;
  }
  final medications = await localDataSource.getAll(uid: uid);
  final reportTime = latestActionTime ?? DateTime.now();
  for (final rangeDays in medicationReportRanges) {
    final previous = await reportLocalDataSource.get(
      uid: uid,
      rangeDays: rangeDays,
    );
    await reportLocalDataSource.save(
      uid: uid,
      report: buildMedicationReport(
        medications: medications,
        rangeDays: rangeDays,
        previousReport: previous,
        now: reportTime,
      ),
    );
  }
  return true;
}

Future<void> _applyActionPayload({
  required String uid,
  required String actionId,
  required Map<String, dynamic> payload,
  required DateTime recordedAt,
  required MedicationLocalDataSource localDataSource,
}) async {
  final targets = <String, _MedicationActionTarget>{};

  void addTargets(dynamic rawItems, {required bool medicine}) {
    for (final raw in rawItems as List<dynamic>? ?? const <dynamic>[]) {
      if (raw is! Map) {
        continue;
      }
      final item = Map<String, dynamic>.from(raw);
      final medicationId = item['medicationId'] as String?;
      final dateKey = item['dateKey'] as String?;
      final doseTime = item['doseTime'] as String?;
      if (medicationId == null || dateKey == null || doseTime == null) {
        continue;
      }
      final target = targets.putIfAbsent(
        medicationId,
        _MedicationActionTarget.new,
      );
      final occurrence = (dateKey: dateKey, doseTime: doseTime);
      if (medicine) {
        target.medicine.add(occurrence);
      } else {
        target.meals.add(occurrence);
      }
    }
  }

  addTargets(payload['doses'], medicine: true);
  addTargets(payload['meals'], medicine: false);
  for (final entry in targets.entries) {
    final medication = await localDataSource.getById(uid: uid, id: entry.key);
    if (medication == null) {
      continue;
    }
    await localDataSource.save(
      uid: uid,
      medication: applyNotificationActionToMedication(
        medication: medication,
        actionId: actionId,
        medicineOccurrences: entry.value.medicine,
        mealOccurrences: entry.value.meals,
        recordedAt: recordedAt,
      ),
    );
  }
}

Medication applyNotificationActionToMedication({
  required Medication medication,
  required String actionId,
  required Iterable<ReminderOccurrence> medicineOccurrences,
  required Iterable<ReminderOccurrence> mealOccurrences,
  required DateTime recordedAt,
}) {
  final medicineKeys = medicineOccurrences.map(_occurrenceKey).toSet();
  final mealKeys = mealOccurrences.map(_occurrenceKey).toSet();
  final allKeys = <String>{...medicineKeys, ...mealKeys};
  final checkIns = <String, MedicationCheckIn>{
    for (final checkIn in medication.checkIns) checkIn.key: checkIn,
  };

  for (final key in allKeys) {
    final separator = key.indexOf('|');
    if (separator < 0) {
      continue;
    }
    final current =
        checkIns[key] ??
        MedicationCheckIn(
          dateKey: key.substring(0, separator),
          doseTime: key.substring(separator + 1),
        );
    final changesMedicine =
        medicineKeys.contains(key) &&
        const <String>{
          medicineTakenAction,
          medicineNotTakenAction,
          allTakenAction,
          allNotTakenAction,
        }.contains(actionId);
    final changesMeal =
        mealKeys.contains(key) &&
        const <String>{
          mealTakenAction,
          mealNotTakenAction,
          allTakenAction,
          allNotTakenAction,
        }.contains(actionId);
    final medicineTaken =
        actionId == medicineTakenAction || actionId == allTakenAction;
    final mealTaken = actionId == mealTakenAction || actionId == allTakenAction;
    checkIns[key] = MedicationCheckIn(
      dateKey: current.dateKey,
      doseTime: current.doseTime,
      medicineStatus: changesMedicine
          ? (medicineTaken ? 'taken' : 'notTaken')
          : current.medicineStatus,
      mealStatus: changesMeal
          ? (mealTaken ? 'taken' : 'notTaken')
          : current.mealStatus,
      medicineTakenAt: changesMedicine && medicineTaken
          ? recordedAt
          : changesMedicine
          ? null
          : current.medicineTakenAt,
      mealTakenAt: changesMeal && mealTaken
          ? recordedAt
          : changesMeal
          ? null
          : current.mealTakenAt,
      takenWithMeal:
          changesMedicine && changesMeal && medicineTaken && mealTaken ||
          (!changesMedicine && !changesMeal && current.takenWithMeal),
    );
  }

  return medication.copyWith(
    checkIns: checkIns.values.toList(growable: false),
    updatedAt: recordedAt,
  );
}

Future<Directory> _actionDirectory() async {
  final support = await getApplicationSupportDirectory();
  final directory = Directory(
    '${support.path}${Platform.pathSeparator}notification_actions',
  );
  await directory.create(recursive: true);
  return directory;
}

Map<String, dynamic>? _decodeMap(String source) {
  final decoded = jsonDecode(source);
  return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
}

String _occurrenceKey(ReminderOccurrence occurrence) {
  return '${occurrence.dateKey}|${occurrence.doseTime}';
}

class _MedicationActionTarget {
  final Set<ReminderOccurrence> medicine = <ReminderOccurrence>{};
  final Set<ReminderOccurrence> meals = <ReminderOccurrence>{};
}
