import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../domain/models/medication.dart';
import '../../domain/repositories/medication_repository.dart';
import '../datasources/medication_local_data_source.dart';
import '../services/medication_notification_service.dart';
import '../services/medication_sync_service.dart';

class MedicationRepositoryImpl implements MedicationRepository {
  MedicationRepositoryImpl({
    required MedicationLocalDataSource localDataSource,
    required MedicationSyncService syncService,
    required MedicationNotificationService notificationService,
    required Connectivity connectivity,
  }) : _localDataSource = localDataSource,
       _syncService = syncService,
       _notificationService = notificationService,
       _connectivity = connectivity;

  final MedicationLocalDataSource _localDataSource;
  final MedicationSyncService _syncService;
  final MedicationNotificationService _notificationService;
  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _retryTimer;
  String? _autoSyncUid;
  bool _hasNetworkConnection = false;

  @override
  Future<void> add({
    required String uid,
    required Medication medication,
  }) async {
    await _localDataSource.save(medication);
    await _rescheduleLocalNotifications();
    _syncService.queueBackup(uid: uid);
  }

  @override
  Future<void> delete({required String uid, required String id}) async {
    final medication = await _localDataSource.getById(id);
    await _localDataSource.delete(id);
    await _rescheduleLocalNotifications();
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
    return _localDataSource.getAll();
  }

  @override
  Future<Medication?> getById(String id) {
    return _localDataSource.getById(id);
  }

  @override
  Future<void> backupToCloud({required String uid}) async {
    await _syncService.backup(uid: uid);
  }

  @override
  Future<void> update({
    required String uid,
    required Medication medication,
  }) async {
    await _localDataSource.save(medication);
    await _rescheduleLocalNotifications();
    _syncService.queueBackup(uid: uid);
  }

  @override
  Future<void> startAutoSync({required String uid}) async {
    await stopAutoSync();
    await _rescheduleLocalNotifications();
    _autoSyncUid = uid;
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      _hasNetworkConnection = _isConnected(results);
      if (_hasNetworkConnection) {
        _syncService.queueBackup(uid: uid);
      }
    });
    _retryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_hasNetworkConnection && _autoSyncUid == uid) {
        _syncService.queueBackup(uid: uid);
      }
    });

    final current = await _connectivity.checkConnectivity();
    _hasNetworkConnection = _isConnected(current);
    if (_hasNetworkConnection) {
      try {
        await _syncService.backup(uid: uid);
      } catch (_) {
        // Local data is already durable. The listener/timer retries later.
      }
    }
  }

  @override
  Future<void> stopAutoSync() async {
    _autoSyncUid = null;
    _hasNetworkConnection = false;
    _retryTimer?.cancel();
    _retryTimer = null;
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  bool _isConnected(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  Future<void> _rescheduleLocalNotifications() async {
    final medications = await _localDataSource.getAll();
    await _notificationService.rescheduleAll(medications);
  }
}
