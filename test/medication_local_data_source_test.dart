import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:medimind/features/medication_reminder/data/datasources/medication_local_data_source.dart';
import 'package:medimind/features/medication_reminder/domain/models/medication.dart';

void main() {
  late Directory tempDirectory;

  setUpAll(() async {
    tempDirectory = await Directory.systemTemp.createTemp('medimind_sync_test');
    Hive.init(tempDirectory.path);
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDirectory.delete(recursive: true);
  });

  test('offline deletions are retained as pending sync operations', () async {
    final source = MedicationLocalDataSource(boxName: 'offline-deletions');
    final medication = Medication(
      id: 'medicine-1',
      medicineName: 'Example',
      dose: '1 pill',
      durationDays: 0,
      timeOfDay: '09:00',
      mealOffset: 0,
      isActive: true,
      updatedAt: DateTime.utc(2026, 7, 22),
    );

    await source.save(medication);
    await source.delete(medication.id);

    expect(await source.getAll(), isEmpty);
    expect(await source.getPendingDeletionIds(), ['medicine-1']);

    await source.save(medication);
    expect(await source.getPendingDeletionIds(), isEmpty);
    expect((await source.getAll()).single.id, 'medicine-1');
  });
}
