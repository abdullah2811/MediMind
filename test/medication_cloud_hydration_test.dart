import 'package:flutter_test/flutter_test.dart';
import 'package:medimind/features/medication_reminder/data/services/medication_sync_service.dart';
import 'package:medimind/features/medication_reminder/domain/models/medication.dart';

Medication _medication(String id, DateTime updatedAt) {
  return Medication(
    id: id,
    medicineName: 'Medicine $id',
    dose: '1 pill',
    durationDays: 0,
    timeOfDay: '09:00',
    mealOffset: 0,
    isActive: true,
    updatedAt: updatedAt,
  );
}

void main() {
  test('cloud-only reminders are selected for local persistence', () {
    final cloud = _medication('cloud-only', DateTime.utc(2026, 7, 23));

    final result = planMedicationCloudHydration(
      localMedications: const [],
      cloudMedications: [cloud],
      pendingDeletionIds: const {},
    );

    expect(result.medicationsToSaveLocally, [cloud]);
    expect(result.cloudBackupRequired, isFalse);
  });

  test('newest reminder version wins in either direction', () {
    final older = _medication('same-id', DateTime.utc(2026, 7, 22));
    final newer = _medication('same-id', DateTime.utc(2026, 7, 23));

    final cloudWins = planMedicationCloudHydration(
      localMedications: [older],
      cloudMedications: [newer],
      pendingDeletionIds: const {},
    );
    expect(cloudWins.medicationsToSaveLocally, [newer]);
    expect(cloudWins.cloudBackupRequired, isFalse);

    final localWins = planMedicationCloudHydration(
      localMedications: [newer],
      cloudMedications: [older],
      pendingDeletionIds: const {},
    );
    expect(localWins.medicationsToSaveLocally, isEmpty);
    expect(localWins.cloudBackupRequired, isTrue);
  });

  test('pending local deletion prevents cloud resurrection', () {
    final cloud = _medication('deleted-id', DateTime.utc(2026, 7, 23));

    final result = planMedicationCloudHydration(
      localMedications: const [],
      cloudMedications: [cloud],
      pendingDeletionIds: const {'deleted-id'},
    );

    expect(result.medicationsToSaveLocally, isEmpty);
    expect(result.cloudBackupRequired, isTrue);
  });
}
