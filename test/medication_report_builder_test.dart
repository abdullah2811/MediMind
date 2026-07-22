import 'package:flutter_test/flutter_test.dart';
import 'package:medimind/features/medication_reminder/domain/models/medication.dart';
import 'package:medimind/features/medication_reminder/domain/models/medication_report.dart';
import 'package:medimind/features/medication_reminder/domain/services/medication_report_builder.dart';

void main() {
  Medication medicineWithCheckIns() => Medication(
    id: 'medicine-1',
    medicineName: 'Napa',
    dose: '1 pill',
    doses: const [
      MedicationDose(timeOfDay: '09:00', dosageValue: '1', dosageUnit: 'pill'),
    ],
    durationDays: 0,
    timeOfDay: '09:00',
    mealOffset: 0,
    mealScheduleEnabled: true,
    checkIns: [
      MedicationCheckIn(
        dateKey: '2026-07-22',
        doseTime: '09:00',
        medicineStatus: 'taken',
        mealStatus: 'taken',
        medicineTakenAt: DateTime(2026, 7, 22, 9, 12),
        mealTakenAt: DateTime(2026, 7, 22, 9, 18),
        takenWithMeal: true,
      ),
      MedicationCheckIn(
        dateKey: '2026-07-14',
        doseTime: '09:00',
        medicineStatus: 'notTaken',
        mealStatus: 'notTaken',
      ),
    ],
    isActive: true,
    updatedAt: DateTime(2026, 7, 22),
  );

  test('report includes detailed actual times inside its fixed range', () {
    final report = buildMedicationReport(
      medications: [medicineWithCheckIns()],
      rangeDays: 7,
      now: DateTime(2026, 7, 22, 12),
    );

    expect(report.periodStart, DateTime(2026, 7, 16));
    expect(report.periodEnd, DateTime(2026, 7, 22, 23, 59, 59, 999));
    expect(report.entries, hasLength(1));
    expect(report.medicinesTaken, 1);
    expect(report.mealsTaken, 1);
    expect(report.entries.single.medicineTakenAt, DateTime(2026, 7, 22, 9, 12));
    expect(report.entries.single.mealTakenAt, DateTime(2026, 7, 22, 9, 18));
  });

  test('30-day report includes older marked activity', () {
    final report = buildMedicationReport(
      medications: [medicineWithCheckIns()],
      rangeDays: 30,
      now: DateTime(2026, 7, 22, 12),
    );

    expect(report.entries, hasLength(2));
    expect(report.medicinesTaken, 1);
    expect(report.medicinesNotTaken, 1);
    expect(report.mealsTaken, 1);
    expect(report.mealsNotTaken, 1);
  });

  test('previous local history is preserved after medicine deletion', () {
    final original = buildMedicationReport(
      medications: [medicineWithCheckIns()],
      rangeDays: 30,
      now: DateTime(2026, 7, 22, 12),
    );
    final refreshed = buildMedicationReport(
      medications: const [],
      rangeDays: 30,
      now: DateTime(2026, 7, 22, 13),
      previousReport: original,
    );

    expect(refreshed.entries, hasLength(2));
    expect(refreshed.entries.first.medicineName, 'Napa');
  });

  test('local report serialization keeps every detail', () {
    final report = buildMedicationReport(
      medications: [medicineWithCheckIns()],
      rangeDays: 7,
      now: DateTime(2026, 7, 22, 12),
    );
    final restored = MedicationReport.fromJson(report.toJson());

    expect(restored.id, 'last_7_days');
    expect(restored.entries.single.takenWithMeal, isTrue);
    expect(restored.entries.single.doseLabel, '1 pill');
  });
}
