import 'package:flutter_test/flutter_test.dart';
import 'package:medimind/features/medication_reminder/domain/models/medication.dart';
import 'package:medimind/features/medication_reminder/domain/services/medication_image_data.dart';

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
      checkIns: [
        MedicationCheckIn(
          dateKey: '2026-07-20',
          doseTime: '08:00',
          medicineStatus: 'taken',
          mealStatus: 'taken',
          medicineTakenAt: DateTime.utc(2026, 7, 20, 8, 12),
          mealTakenAt: DateTime.utc(2026, 7, 20, 8, 30),
          takenWithMeal: true,
        ),
      ],
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
    expect(restored.checkIns.single.medicineStatus, 'taken');
    expect(restored.checkIns.single.takenWithMeal, isTrue);
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
    expect(restored.scheduleFrequency, 'daily');
    expect(restored.occursOnDate(DateTime(2026, 7, 21)), isTrue);
  });

  test('local medicine artwork is decoded safely', () {
    final medicine = Medication(
      id: 'photo',
      medicineName: 'Photo medicine',
      dose: '1 pill',
      durationDays: 0,
      timeOfDay: '09:00',
      mealOffset: 0,
      imageBytesBase64: 'AQID',
      backupImageUrl: 'https://example.com/photo.jpg',
      isActive: true,
      updatedAt: DateTime(2026, 7, 22),
    );

    expect(medicationImageBytes(medicine), [1, 2, 3]);
    expect(
      medicationNetworkImageUrl(medicine),
      'https://example.com/photo.jpg',
    );
    expect(
      medicationImageBytes(medicine.copyWith(imageBytesBase64: '%%%')),
      isNull,
    );
  });

  test('all supported recurrence rules calculate their dates correctly', () {
    Medication scheduled(String frequency, {int customDays = 1}) => Medication(
      id: frequency,
      medicineName: frequency,
      dose: '1 pill',
      durationDays: 0,
      timeOfDay: '09:00',
      mealOffset: 0,
      scheduleFrequency: frequency,
      customIntervalDays: customDays,
      scheduleStartDate: DateTime(2026, 1, 31),
      isActive: true,
      updatedAt: DateTime(2026, 1, 31),
    );

    expect(scheduled('daily').occursOnDate(DateTime(2026, 2, 1)), isTrue);
    expect(scheduled('weekly').occursOnDate(DateTime(2026, 2, 7)), isTrue);
    expect(
      scheduled('every15Days').occursOnDate(DateTime(2026, 2, 15)),
      isTrue,
    );
    expect(scheduled('monthly').occursOnDate(DateTime(2026, 2, 28)), isTrue);
    expect(
      scheduled('custom', customDays: 3).occursOnDate(DateTime(2026, 2, 3)),
      isTrue,
    );
    expect(
      scheduled('custom', customDays: 3).occursOnDate(DateTime(2026, 2, 2)),
      isFalse,
    );
  });
}
