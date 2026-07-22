import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../domain/models/medication.dart';
import '../../domain/models/medication_report.dart';
import '../../domain/repositories/medication_repository.dart';
import '../../domain/services/medication_report_builder.dart';
import '../datasources/medication_local_data_source.dart';
import '../datasources/medication_report_local_data_source.dart';
import '../services/medication_notification_action_handler.dart';
import '../services/medication_notification_service.dart';
import '../services/medication_sync_service.dart';

class MedicationRepositoryImpl implements MedicationRepository {
  MedicationRepositoryImpl({
    required MedicationLocalDataSource localDataSource,
    required MedicationReportLocalDataSource reportLocalDataSource,
    required MedicationSyncService syncService,
    required MedicationNotificationService notificationService,
    required Connectivity connectivity,
  }) : _localDataSource = localDataSource,
       _reportLocalDataSource = reportLocalDataSource,
       _syncService = syncService,
       _notificationService = notificationService,
       _connectivity = connectivity;

  final MedicationLocalDataSource _localDataSource;
  final MedicationReportLocalDataSource _reportLocalDataSource;
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
    await _refreshReports(uid: uid);
    await _rescheduleLocalNotifications(uid: uid);
    _syncService.queueBackup(uid: uid);
  }

  @override
  Future<void> delete({required String uid, required String id}) async {
    await _localDataSource.delete(id);
    await _refreshReports(uid: uid);
    await _rescheduleLocalNotifications(uid: uid);
    _syncService.queueBackup(uid: uid);
  }

  @override
  Future<List<Medication>> getAll({required String uid}) async {
    await _applyPendingNotificationActions(uid);
    return _localDataSource.getAll();
  }

  @override
  Future<Medication?> getById(String id) {
    return _localDataSource.getById(id);
  }

  @override
  Future<void> backupToCloud({required String uid}) async {
    await _refreshReports(uid: uid, queueCloudBackup: false);
    _syncService.resumeCloudBackups();
    await _syncService.backup(uid: uid);
  }

  @override
  Future<MedicationReport> getReport({
    required String uid,
    required int rangeDays,
  }) async {
    await _applyPendingNotificationActions(uid);
    final medications = await _localDataSource.getAll();
    final previous = await _reportLocalDataSource.get(
      uid: uid,
      rangeDays: rangeDays,
    );
    final report = buildMedicationReport(
      medications: medications,
      rangeDays: rangeDays,
      previousReport: previous,
    );
    await _reportLocalDataSource.save(uid: uid, report: report);
    _syncService.queueBackup(uid: uid);
    return report;
  }

  @override
  Future<void> update({
    required String uid,
    required Medication medication,
  }) async {
    await _localDataSource.save(medication);
    await _refreshReports(uid: uid);
    await _rescheduleLocalNotifications(uid: uid);
    _syncService.queueBackup(uid: uid);
  }

  @override
  Future<void> startAutoSync({required String uid}) async {
    await stopAutoSync();
    await _applyPendingNotificationActions(uid);
    _syncService.startSession(uid);
    await _refreshReports(uid: uid, queueCloudBackup: false);
    await _rescheduleLocalNotifications(uid: uid);
    _autoSyncUid = uid;
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      _hasNetworkConnection = _isConnected(results);
      if (_hasNetworkConnection) {
        _syncService.notifyConnectivityRestored();
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
      _syncService.queueBackup(uid: uid);
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

  Future<void> _applyPendingNotificationActions(String uid) async {
    await applyPendingMedicationNotificationActions(
      uid: uid,
      localDataSource: _localDataSource,
      reportLocalDataSource: _reportLocalDataSource,
    );
  }

  Future<void> _rescheduleLocalNotifications({required String uid}) async {
    final medications = await _localDataSource.getAll();
    try {
      await _notificationService.rescheduleAll(medications, uid: uid);
    } catch (_) {
      // The local database is the source of truth. Notification permission or
      // platform failures must never make a successful local save look failed.
    }
  }

  Future<void> _refreshReports({
    required String uid,
    bool queueCloudBackup = true,
  }) async {
    final medications = await _localDataSource.getAll();
    for (final rangeDays in medicationReportRanges) {
      final previous = await _reportLocalDataSource.get(
        uid: uid,
        rangeDays: rangeDays,
      );
      final report = buildMedicationReport(
        medications: medications,
        rangeDays: rangeDays,
        previousReport: previous,
      );
      await _reportLocalDataSource.save(uid: uid, report: report);
      if (queueCloudBackup) {
        _syncService.queueBackup(uid: uid);
      }
    }
  }
}
