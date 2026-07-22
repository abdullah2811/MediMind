import '../models/medication.dart';
import '../models/medication_report.dart';

const medicationReportRanges = <int>[7, 30];

MedicationReport buildMedicationReport({
  required List<Medication> medications,
  required int rangeDays,
  DateTime? now,
  MedicationReport? previousReport,
}) {
  final generatedAt = now ?? DateTime.now();
  final end = DateTime(
    generatedAt.year,
    generatedAt.month,
    generatedAt.day + 1,
  ).subtract(const Duration(milliseconds: 1));
  final start = DateTime(end.year, end.month, end.day - rangeDays + 1);
  final entriesById = <String, MedicationReportEntry>{};

  for (final entry
      in previousReport?.entries ?? const <MedicationReportEntry>[]) {
    if (!entry.scheduledAt.isBefore(start) && !entry.scheduledAt.isAfter(end)) {
      entriesById[entry.id] = entry;
    }
  }

  for (final medication in medications) {
    for (final checkIn in medication.checkIns) {
      final scheduledAt = _scheduledAt(checkIn);
      if (scheduledAt == null ||
          scheduledAt.isBefore(start) ||
          scheduledAt.isAfter(end)) {
        continue;
      }
      MedicationDose? dose;
      for (final item in medication.effectiveDoses) {
        if (item.timeOfDay == checkIn.doseTime) {
          dose = item;
          break;
        }
      }
      final entryId = '${medication.id}|${checkIn.key}';
      entriesById[entryId] = MedicationReportEntry(
        id: entryId,
        medicationId: medication.id,
        medicineName: medication.medicineName,
        doseLabel: dose == null
            ? medication.dose
            : '${dose.dosageValue} ${dose.dosageUnit}'.trim(),
        scheduledAt: scheduledAt,
        medicineStatus: checkIn.medicineStatus,
        medicineTakenAt: checkIn.medicineTakenAt,
        mealStatus: checkIn.mealStatus,
        mealTakenAt: checkIn.mealTakenAt,
        takenWithMeal: checkIn.takenWithMeal,
      );
    }
  }

  final entries = entriesById.values.toList(growable: false)
    ..sort((left, right) => right.scheduledAt.compareTo(left.scheduledAt));
  return MedicationReport(
    id: 'last_${rangeDays}_days',
    rangeDays: rangeDays,
    periodStart: start,
    periodEnd: end,
    generatedAt: generatedAt,
    entries: entries,
  );
}

DateTime? _scheduledAt(MedicationCheckIn checkIn) {
  final date = DateTime.tryParse(checkIn.dateKey);
  final timeParts = checkIn.doseTime.split(':');
  if (date == null || timeParts.length != 2) {
    return null;
  }
  final hour = int.tryParse(timeParts[0]);
  final minute = int.tryParse(timeParts[1]);
  if (hour == null || minute == null) {
    return null;
  }
  return DateTime(date.year, date.month, date.day, hour, minute);
}
