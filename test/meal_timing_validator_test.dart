import 'package:flutter_test/flutter_test.dart';
import 'package:medimind/features/medication_reminder/domain/models/medication.dart';
import 'package:medimind/features/medication_reminder/domain/services/meal_timing_validator.dart';

void main() {
  Medication existingMedicine({
    String doseTime = '21:00',
    int mealOffset = -20,
  }) {
    return Medication(
      id: 'existing',
      medicineName: 'Existing medicine',
      dose: '1 pill',
      doses: [
        MedicationDose(
          timeOfDay: doseTime,
          dosageValue: '1',
          dosageUnit: 'pill',
        ),
      ],
      durationDays: 0,
      timeOfDay: doseTime,
      mealOffset: mealOffset,
      mealScheduleEnabled: true,
      isActive: true,
      updatedAt: DateTime(2026, 7, 22),
    );
  }

  test('contradictory nearby meal anchors return the corrected dose time', () {
    final conflict = findMealTimingConflict(
      newDoseTimes: const ['21:30'],
      newMealOffset: 30,
      existingMedications: [existingMedicine()],
    );

    expect(conflict, isNotNull);
    expect(conflict!.requestedMedicineTime, '21:30');
    expect(conflict.requestedMealTime, '21:00');
    expect(conflict.existingMealTime, '21:20');
    expect(conflict.suggestedMedicineTime, '21:50');
  });

  test('a dose aligned to the existing meal is accepted', () {
    final conflict = findMealTimingConflict(
      newDoseTimes: const ['21:50'],
      newMealOffset: 30,
      existingMedications: [existingMedicine()],
    );

    expect(conflict, isNull);
  });

  test('unrelated meal times remain valid', () {
    final conflict = findMealTimingConflict(
      newDoseTimes: const ['23:30'],
      newMealOffset: 30,
      existingMedications: [existingMedicine()],
    );

    expect(conflict, isNull);
  });

  test('meal-window validation works across midnight', () {
    final conflict = findMealTimingConflict(
      newDoseTimes: const ['00:40'],
      newMealOffset: 30,
      existingMedications: [
        existingMedicine(doseTime: '23:30', mealOffset: -20),
      ],
    );

    expect(conflict, isNotNull);
    expect(conflict!.requestedMealTime, '00:10');
    expect(conflict.existingMealTime, '23:50');
    expect(conflict.suggestedMedicineTime, '00:20');
  });
}
