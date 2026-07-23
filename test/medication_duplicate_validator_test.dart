import 'package:flutter_test/flutter_test.dart';
import 'package:medimind/features/medication_reminder/domain/models/medication.dart';
import 'package:medimind/features/medication_reminder/domain/services/medication_duplicate_validator.dart';

void main() {
  Medication medication({
    String id = 'existing',
    String name = 'Napa',
    String? formula = 'Paracetamol',
    String dosage = '1',
    String unit = 'pill',
  }) {
    return Medication(
      id: id,
      medicineName: name,
      formula: formula,
      dose: dosage,
      doses: [
        MedicationDose(
          timeOfDay: '09:00',
          dosageValue: dosage,
          dosageUnit: unit,
        ),
      ],
      durationDays: 0,
      timeOfDay: '09:00',
      mealOffset: 0,
      isActive: true,
      updatedAt: DateTime(2026, 7, 22),
    );
  }

  test('rejects a reminder when any two identity fields match', () {
    final existing = medication();
    final match = findMatchingMedication(
      medicineName: ' napa ',
      formula: 'Different formula',
      doses: const [
        MedicationDose(
          timeOfDay: '18:00',
          dosageValue: '1',
          dosageUnit: 'pill',
        ),
      ],
      existingMedications: [existing],
    );

    expect(match, same(existing));
  });

  test('allows a reminder when only one identity field matches', () {
    final match = findMatchingMedication(
      medicineName: 'Napa',
      formula: 'Different formula',
      doses: const [
        MedicationDose(
          timeOfDay: '18:00',
          dosageValue: '2',
          dosageUnit: 'pill',
        ),
      ],
      existingMedications: [medication()],
    );

    expect(match, isNull);
  });

  test('does not compare an item with itself while editing', () {
    final match = findMatchingMedication(
      medicineName: 'Napa',
      formula: 'Paracetamol',
      doses: const [
        MedicationDose(
          timeOfDay: '18:00',
          dosageValue: '1',
          dosageUnit: 'pill',
        ),
      ],
      existingMedications: [medication()],
      excludedMedicationId: 'existing',
    );

    expect(match, isNull);
  });
}
