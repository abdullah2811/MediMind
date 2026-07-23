import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:medimind/features/medication_reminder/data/datasources/medication_local_data_source.dart';
import 'package:medimind/features/medication_reminder/data/datasources/medication_report_local_data_source.dart';
import 'package:medimind/features/medication_reminder/domain/models/medication.dart';
import 'package:medimind/features/medication_reminder/domain/models/medication_report.dart';

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

    await source.save(uid: 'owner-1', medication: medication);
    await source.delete(uid: 'owner-1', id: medication.id);

    expect(await source.getAll(uid: 'owner-1'), isEmpty);
    expect(await source.getPendingDeletionIds(uid: 'owner-1'), ['medicine-1']);

    await source.save(uid: 'owner-1', medication: medication);
    expect(await source.getPendingDeletionIds(uid: 'owner-1'), isEmpty);
    expect((await source.getAll(uid: 'owner-1')).single.id, 'medicine-1');
  });

  test('local medicines are isolated by account on one device', () async {
    final source = MedicationLocalDataSource(boxName: 'account-isolation');
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

    await source.save(uid: 'owner-1', medication: medication);

    expect(await source.getAll(uid: 'owner-1'), hasLength(1));
    expect(await source.getAll(uid: 'owner-2'), isEmpty);
  });

  test('reports are persisted locally per account and range', () async {
    final source = MedicationReportLocalDataSource(boxName: 'local-reports');
    final report = MedicationReport(
      id: 'last_7_days',
      rangeDays: 7,
      periodStart: DateTime(2026, 7, 16),
      periodEnd: DateTime(2026, 7, 22, 23, 59, 59, 999),
      generatedAt: DateTime(2026, 7, 22, 12),
      entries: [
        MedicationReportEntry(
          id: 'medicine-1|2026-07-22|09:00',
          medicationId: 'medicine-1',
          medicineName: 'Napa',
          doseLabel: '1 pill',
          scheduledAt: DateTime(2026, 7, 22, 9),
          medicineStatus: 'taken',
          medicineTakenAt: DateTime(2026, 7, 22, 9, 5),
        ),
      ],
    );

    await source.save(uid: 'owner-1', report: report);

    final restored = await source.get(uid: 'owner-1', rangeDays: 7);
    expect(restored, isNotNull);
    expect(restored!.entries.single.medicineName, 'Napa');
    expect(await source.get(uid: 'owner-2', rangeDays: 7), isNull);
    expect(await source.getAll(uid: 'owner-1'), hasLength(1));
  });
}
