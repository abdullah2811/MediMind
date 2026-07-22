import '../models/medication.dart';
import '../models/medication_report.dart';

abstract class MedicationRepository {
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
