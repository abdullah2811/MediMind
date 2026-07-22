import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../datasources/medication_local_data_source.dart';
import '../datasources/medication_report_local_data_source.dart';
import '../datasources/medication_report_remote_data_source.dart';
import '../datasources/medication_remote_data_source.dart';
import '../../domain/models/medication.dart';

class MedicationSyncService {
  MedicationSyncService({
    required FirebaseFirestore firestore,
    required FirebaseStorage storage,
    required MedicationLocalDataSource localDataSource,
    required MedicationReportLocalDataSource reportLocalDataSource,
    required MedicationReportRemoteDataSource reportRemoteDataSource,
    required MedicationRemoteDataSource remoteDataSource,
  }) : _storage = storage,
       _localDataSource = localDataSource,
       _reportLocalDataSource = reportLocalDataSource,
       _reportRemoteDataSource = reportRemoteDataSource,
       _remoteDataSource = remoteDataSource;

  final FirebaseStorage _storage;
  final MedicationLocalDataSource _localDataSource;
  final MedicationReportLocalDataSource _reportLocalDataSource;
  final MedicationReportRemoteDataSource _reportRemoteDataSource;
  final MedicationRemoteDataSource _remoteDataSource;
  Future<void>? _backupInFlight;
  String? _sessionUid;
  DateTime? _retryAfter;
  int _failureCount = 0;
  bool _cloudBackupPaused = false;
  bool _pauseWasLogged = false;

  void startSession(String uid) {
    if (_sessionUid == uid) {
      return;
    }
    _sessionUid = uid;
    resumeCloudBackups();
  }

  void notifyConnectivityRestored() {
    if (_cloudBackupPaused) {
      return;
    }
    _failureCount = 0;
    _retryAfter = null;
  }

  void resumeCloudBackups() {
    _cloudBackupPaused = false;
    _pauseWasLogged = false;
    _failureCount = 0;
    _retryAfter = null;
  }

  void queueBackup({required String uid}) {
    startSession(uid);
    if (_cloudBackupPaused || (_retryAfter?.isAfter(DateTime.now()) ?? false)) {
      return;
    }
    unawaited(backup(uid: uid).catchError((Object _, StackTrace __) {}));
  }

  Future<String> uploadMedicationPhoto({
    required String userId,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    final safeFileName = fileName.isNotEmpty
        ? fileName
        : 'medicine_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref('medication_images/$userId/$safeFileName');
    await ref
        .putData(fileBytes, SettableMetadata(contentType: 'image/jpeg'))
        .timeout(const Duration(seconds: 30));
    return ref.getDownloadURL().timeout(const Duration(seconds: 20));
  }

  Future<void> backupLocalToCloud({required String uid}) async {
    final pendingDeletionIds = await _localDataSource.getPendingDeletionIds();
    for (final id in pendingDeletionIds) {
      await _remoteDataSource
          .deleteMedication(uid: uid, id: id)
          .timeout(const Duration(seconds: 20));
      await _deleteMedicationPhotoIfPresent(userId: uid, medicationId: id);
      await _localDataSource.clearPendingDeletion(id);
    }

    final localMedications = await _localDataSource.getAll();
    for (final medication in localMedications) {
      final cloudImageUrl = await _uploadMedicationImageIfNeeded(
        userId: uid,
        medication: medication,
      );
      final backedUpMedication = medication.copyWith(
        backupImageUrl: cloudImageUrl,
      );
      await _remoteDataSource
          .upsertMedication(uid: uid, medication: backedUpMedication)
          .timeout(const Duration(seconds: 20));
      if (cloudImageUrl != medication.backupImageUrl) {
        await _localDataSource.save(backedUpMedication);
      }
    }

    final reports = await _reportLocalDataSource.getAll(uid: uid);
    for (final report in reports) {
      await _reportRemoteDataSource
          .upsertReport(uid: uid, report: report)
          .timeout(const Duration(seconds: 20));
    }
  }

  Future<void> _deleteMedicationPhotoIfPresent({
    required String userId,
    required String medicationId,
  }) async {
    try {
      await _storage
          .ref('medication_images/$userId/$medicationId.jpg')
          .delete()
          .timeout(const Duration(seconds: 20));
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') {
        rethrow;
      }
    }
  }

  Future<String?> _uploadMedicationImageIfNeeded({
    required String userId,
    required Medication medication,
  }) async {
    final existingImageUrl = medication.backupImageUrl;
    if (existingImageUrl != null && existingImageUrl.isNotEmpty) {
      return existingImageUrl;
    }

    final imageBytesBase64 = medication.imageBytesBase64;
    if (imageBytesBase64 == null || imageBytesBase64.isEmpty) {
      return medication.imagePath;
    }

    final bytes = base64Decode(imageBytesBase64);
    return uploadMedicationPhoto(
      userId: userId,
      fileBytes: bytes,
      fileName: '${medication.id}.jpg',
    );
  }

  Future<void> backup({required String uid}) async {
    final running = _backupInFlight;
    if (running != null) {
      return running;
    }

    late final Future<void> operation;
    operation = _backup(uid)
        .then((_) {
          _failureCount = 0;
          _retryAfter = null;
        })
        .onError((Object error, StackTrace stackTrace) {
          _recordBackupFailure(error);
          Error.throwWithStackTrace(error, stackTrace);
        })
        .whenComplete(() {
          if (identical(_backupInFlight, operation)) {
            _backupInFlight = null;
          }
        });
    _backupInFlight = operation;
    return operation;
  }

  Future<void> _backup(String uid) async {
    await backupLocalToCloud(uid: uid);
  }

  void _recordBackupFailure(Object error) {
    if (_isPermissionDenied(error) || _isFirestoreInternalAssertion(error)) {
      _cloudBackupPaused = true;
      _retryAfter = null;
      if (!_pauseWasLogged) {
        final reason = _isPermissionDenied(error)
            ? 'Firestore denied access. Deploy the project rules and use the '
                  'Backup button to retry.'
            : 'the Firestore web client entered an invalid state. Restart the '
                  'app after correcting Firebase access, then retry Backup.';
        debugPrint('Medication cloud backup paused: $reason');
        _pauseWasLogged = true;
      }
      return;
    }

    _failureCount = (_failureCount + 1).clamp(1, 5);
    final delay = Duration(minutes: 1 << (_failureCount - 1));
    _retryAfter = DateTime.now().add(delay);
    debugPrint(
      'Medication cloud backup deferred for ${delay.inMinutes} minute(s): '
      '$error',
    );
  }

  bool _isPermissionDenied(Object error) {
    return error is FirebaseException && error.code == 'permission-denied' ||
        error.toString().contains('permission-denied');
  }

  bool _isFirestoreInternalAssertion(Object error) {
    final message = error.toString();
    return message.contains('FIRESTORE') &&
        message.contains('INTERNAL ASSERTION FAILED');
  }
}
