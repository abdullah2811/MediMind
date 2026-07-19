import '../../domain/models/medication.dart';
import '../../domain/repositories/medication_repository.dart';
import '../datasources/medication_local_data_source.dart';
import '../datasources/medication_remote_data_source.dart';
import '../services/medication_notification_service.dart';
import '../services/medication_sync_service.dart';

class MedicationRepositoryImpl implements MedicationRepository {
  MedicationRepositoryImpl({
    required MedicationLocalDataSource localDataSource,
    required MedicationRemoteDataSource remoteDataSource,
    required MedicationSyncService syncService,
    required MedicationNotificationService notificationService,
  }) : _localDataSource = localDataSource,
       _remoteDataSource = remoteDataSource,
       _syncService = syncService,
       _notificationService = notificationService;

  final MedicationLocalDataSource _localDataSource;
  final MedicationRemoteDataSource _remoteDataSource;
  final MedicationSyncService _syncService;
  final MedicationNotificationService _notificationService;

  @override
  Future<void> add({
    required String uid,
    required Medication medication,
  }) async {
    await _localDataSource.save(medication);
    await _notificationService.scheduleMedication(medication);
    _syncService.queuePush(
      uid: uid,
      medication: medication,
      operation: SyncOperation.upsert,
    );
  }

  @override
  Future<void> delete({required String uid, required String id}) async {
    final medication = await _localDataSource.getById(id);
    await _localDataSource.delete(id);
    await _notificationService.cancelMedication(id);
    if (medication != null) {
      _syncService.queuePush(
        uid: uid,
        medication: medication,
        operation: SyncOperation.delete,
      );
    }
  }

  @override
  Future<List<Medication>> getAll({required String uid}) async {
    final localMedications = await _localDataSource.getAll();
    if (localMedications.isNotEmpty) {
      return localMedications;
    }
    return _remoteDataSource.fetchForUser(uid);
  }

  @override
  Future<Medication?> getById(String id) {
    return _localDataSource.getById(id);
  }

  @override
  Future<void> syncFromCloud({required String uid}) async {
    await _syncService.syncFromCloud(uid: uid);
  }

  @override
  Future<void> backupToCloud({required String uid}) async {
    await _syncService.backupLocalToCloud(uid: uid);
  }

  @override
  Future<void> update({
    required String uid,
    required Medication medication,
  }) async {
    await _localDataSource.save(medication);
    await _notificationService.scheduleMedication(medication);
    _syncService.queuePush(
      uid: uid,
      medication: medication,
      operation: SyncOperation.upsert,
    );
  }
}
