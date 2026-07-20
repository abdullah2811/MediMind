import 'package:flutter_test/flutter_test.dart';
import 'package:medimind/features/medication_reminder/domain/models/medication.dart';

void main() {
  test('meal time is calculated from the medicine-to-meal relation', () {
    expect(calculateMealTime('09:00', -30), '09:30');
    expect(calculateMealTime('09:00', 0), '09:00');
    expect(calculateMealTime('09:00', 30), '08:30');
  });

  test('structured doses and medicine details survive local serialization', () {
    final medication = Medication(
      id: 'medicine-1',
      medicineName: 'Example',
      medicineType: 'syrup',
      powerValue: '125',
      powerUnit: 'mg',
      dose: '08:00 — 5 ml',
      durationDays: 0,
      timeOfDay: '08:00',
      doseTimes: const ['08:00'],
      doses: const [
        MedicationDose(timeOfDay: '08:00', dosageValue: '5', dosageUnit: 'ml'),
      ],
      mealOffset: -30,
      mealScheduleEnabled: true,
      mealTimes: const ['08:30'],
      isActive: true,
      updatedAt: DateTime.utc(2026, 7, 20),
    );

    final restored = Medication.fromJson(medication.toJson());

    expect(restored.medicineType, 'syrup');
    expect(restored.powerLabel, '125 mg');
    expect(restored.mealScheduleEnabled, isTrue);
    expect(restored.mealTimes, const ['08:30']);
    expect(restored.doses.single.timeOfDay, '08:00');
    expect(restored.doses.single.dosageValue, '5');
    expect(restored.doses.single.dosageUnit, 'ml');
  });

  test('legacy medicine records remain readable and reminders are enabled', () {
    final restored = Medication.fromJson({
      'id': 'legacy',
      'medicineName': 'Legacy medicine',
      'dose': '1 tablet',
      'timeOfDay': '21:00',
      'mealOffset': 0,
      'isActive': false,
      'updatedAt': '2026-07-20T00:00:00.000Z',
    });

    expect(restored.medicineType, 'tablet');
    expect(restored.isActive, isTrue);
    expect(restored.effectiveDoses.single.timeOfDay, '21:00');
    expect(restored.effectiveDoses.single.dosageValue, '1 tablet');
  });
}
