import 'package:flutter_test/flutter_test.dart';
import 'package:medimind/features/medication_reminder/data/services/medication_notification_action_handler.dart';
import 'package:medimind/features/medication_reminder/domain/models/medication.dart';

void main() {
  final medication = Medication(
    id: 'medicine-1',
    medicineName: 'Napa',
    dose: '1 pill',
    durationDays: 0,
    timeOfDay: '09:00',
    mealOffset: 0,
    isActive: true,
    updatedAt: DateTime(2026, 7, 22),
  );
  const occurrence = (dateKey: '2026-07-22', doseTime: '09:00');

  test('medicine notification action records a local taken check-in', () {
    final recordedAt = DateTime(2026, 7, 22, 9, 3);
    final updated = applyNotificationActionToMedication(
      medication: medication,
      actionId: medicineTakenAction,
      medicineOccurrences: const [occurrence],
      mealOccurrences: const [],
      recordedAt: recordedAt,
    );

    expect(updated.checkIns.single.medicineStatus, 'taken');
    expect(updated.checkIns.single.medicineTakenAt, recordedAt);
    expect(updated.checkIns.single.mealStatus, isNull);
  });

  test('combined notification action records medicine and meal together', () {
    final recordedAt = DateTime(2026, 7, 22, 9, 1);
    final updated = applyNotificationActionToMedication(
      medication: medication,
      actionId: allTakenAction,
      medicineOccurrences: const [occurrence],
      mealOccurrences: const [occurrence],
      recordedAt: recordedAt,
    );

    final checkIn = updated.checkIns.single;
    expect(checkIn.medicineStatus, 'taken');
    expect(checkIn.mealStatus, 'taken');
    expect(checkIn.takenWithMeal, isTrue);
  });

  test('not-taken action clears a previous taken timestamp', () {
    final withTakenStatus = medication.copyWith(
      checkIns: [
        MedicationCheckIn(
          dateKey: occurrence.dateKey,
          doseTime: occurrence.doseTime,
          medicineStatus: 'taken',
          medicineTakenAt: DateTime(2026, 7, 22, 9),
        ),
      ],
    );
    final updated = applyNotificationActionToMedication(
      medication: withTakenStatus,
      actionId: medicineNotTakenAction,
      medicineOccurrences: const [occurrence],
      mealOccurrences: const [],
      recordedAt: DateTime(2026, 7, 22, 9, 5),
    );

    expect(updated.checkIns.single.medicineStatus, 'notTaken');
    expect(updated.checkIns.single.medicineTakenAt, isNull);
  });
}
