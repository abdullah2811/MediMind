import '../models/medication.dart';

abstract class MedicationRepository {
  Future<List<Medication>> getAll({required String uid});
  Future<Medication?> getById(String id);
  Future<void> add({required String uid, required Medication medication});
  Future<void> update({required String uid, required Medication medication});
  Future<void> delete({required String uid, required String id});
  Future<void> syncFromCloud({required String uid});
  Future<void> backupToCloud({required String uid});
}
