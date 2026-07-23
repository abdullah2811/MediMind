import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

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
  bool _hasNetworkConnection = false;
  Future<void>? _postMutationWork;
  int _postMutationRevision = 0;
  int _processedMutationRevision = 0;
  String? _postMutationUid;

  @override
  Stream<String> get automaticBackupSucceeded =>
      _syncService.automaticBackupSucceeded;

  @override
  Stream<bool> get backupInProgressChanged =>
      _syncService.backupInProgressChanged;

  @override
  bool get isBackupInProgress => _syncService.isBackupInProgress;

  @override
  Stream<String> get openedReminderPayloads =>
      _notificationService.openedReminderPayloads;

  @override
  String? takePendingOpenedReminderPayload() =>
      _notificationService.takePendingOpenedReminderPayload();

  @override
  Future<void> add({
    required String uid,
    required Medication medication,
  }) async {
    await _localDataSource.save(uid: uid, medication: medication);
    _queuePostMutationWork(uid);
  }

  @override
  Future<void> delete({required String uid, required String id}) async {
    await _localDataSource.delete(uid: uid, id: id);
    _queuePostMutationWork(uid);
  }

  @override
  Future<List<Medication>> getAll({required String uid}) async {
    if (await _applyPendingNotificationActions(uid)) {
      _syncService.queueBackup(uid: uid);
    }
    return _localDataSource.getAll(uid: uid);
  }

  @override
  Future<Medication?> getById({required String uid, required String id}) {
    return _localDataSource.getById(uid: uid, id: id);
  }

  @override
  Future<void> backupToCloud({required String uid}) async {
    await _refreshReports(uid: uid);
    _syncService.resumeCloudBackups();
    await _syncService.backupNow(uid: uid);
  }

  @override
  Future<MedicationReport> getReport({
    required String uid,
    required int rangeDays,
  }) async {
    await _applyPendingNotificationActions(uid);
    final medications = await _localDataSource.getAll(uid: uid);
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
    return report;
  }

  @override
  Future<void> update({
    required String uid,
    required Medication medication,
  }) async {
    await _localDataSource.save(uid: uid, medication: medication);
    _queuePostMutationWork(uid);
  }

  @override
  Future<void> startAutoSync({required String uid}) async {
    await stopAutoSync();
    final notificationActionChangedState =
        await _applyPendingNotificationActions(uid);
    _syncService.startSession(uid);
    var cloudBackupRequired = notificationActionChangedState;
    try {
      final hydration = await _syncService.hydrateLocalFromCloud(uid: uid);
      cloudBackupRequired =
          cloudBackupRequired || hydration.cloudBackupRequired;
    } catch (error, stackTrace) {
      cloudBackupRequired = true;
      debugPrint('Medication cloud restore deferred: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    await _refreshReports(uid: uid);
    await _rescheduleLocalNotifications(uid: uid);
    if (cloudBackupRequired) {
      _syncService.queueBackup(uid: uid);
    }
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      _hasNetworkConnection = _isConnected(results);
      if (_hasNetworkConnection) {
        _syncService.notifyConnectivityRestored();
        _syncService.retryPendingBackup(uid: uid);
      }
    });
    final current = await _connectivity.checkConnectivity();
    _hasNetworkConnection = _isConnected(current);
  }

  @override
  Future<void> stopAutoSync() async {
    _hasNetworkConnection = false;
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  bool _isConnected(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  Future<bool> _applyPendingNotificationActions(String uid) {
    return applyPendingMedicationNotificationActions(
      uid: uid,
      localDataSource: _localDataSource,
      reportLocalDataSource: _reportLocalDataSource,
    );
  }

  void _queuePostMutationWork(String uid) {
    _syncService.markBackupPending(uid: uid);
    _postMutationUid = uid;
    _postMutationRevision++;
    if (_postMutationWork != null) {
      return;
    }
    _startPostMutationWork();
  }

  void _startPostMutationWork() {
    final operation = _drainPostMutationWork();
    _postMutationWork = operation;
    unawaited(
      operation.whenComplete(() {
        _postMutationWork = null;
        if (_processedMutationRevision < _postMutationRevision) {
          _startPostMutationWork();
        }
      }),
    );
  }

  Future<void> _drainPostMutationWork() async {
    while (_processedMutationRevision < _postMutationRevision) {
      final targetRevision = _postMutationRevision;
      final uid = _postMutationUid;
      if (uid == null) {
        _processedMutationRevision = targetRevision;
        continue;
      }
      try {
        await _refreshReports(uid: uid);
        await _rescheduleLocalNotifications(uid: uid);
      } catch (error, stackTrace) {
        debugPrint('Medication background maintenance failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      _processedMutationRevision = targetRevision;
    }
    final uid = _postMutationUid;
    if (uid != null) {
      _syncService.runPreparedBackup(uid: uid);
    }
  }

  Future<void> _rescheduleLocalNotifications({required String uid}) async {
    final medications = await _localDataSource.getAll(uid: uid);
    try {
      await _notificationService.rescheduleAll(medications, uid: uid);
    } catch (error, stackTrace) {
      // The local database is the source of truth. Notification permission or
      // platform failures must never make a successful local save look failed.
      debugPrint('Medication reminder scheduling failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _refreshReports({required String uid}) async {
    final medications = await _localDataSource.getAll(uid: uid);
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
    }
  }
}
