import '../models/medication.dart';
import '../models/medication_report.dart';

abstract class MedicationRepository {
  Stream<String> get automaticBackupSucceeded => const Stream<String>.empty();
  Stream<String> get openedReminderPayloads => const Stream<String>.empty();

  String? takePendingOpenedReminderPayload() => null;

  Future<List<Medication>> getAll({required String uid});
  Future<Medication?> getById(String id);
  Future<void> add({required String uid, required Medication medication});
  Future<void> update({required String uid, required Medication medication});
  Future<void> delete({required String uid, required String id});
  Future<void> backupToCloud({required String uid});
  Future<MedicationReport> getReport({
    required String uid,
    required int rangeDays,
  });
  Future<void> startAutoSync({required String uid});
  Future<void> stopAutoSync();
}
