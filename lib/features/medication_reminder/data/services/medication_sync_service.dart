import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../datasources/medication_local_data_source.dart';
import '../datasources/medication_remote_data_source.dart';
import '../../domain/models/medication.dart';
import 'medication_notification_service.dart';

class MedicationSyncService {
  MedicationSyncService({
    required FirebaseFirestore firestore,
    required FirebaseStorage storage,
    required MedicationLocalDataSource localDataSource,
    required MedicationRemoteDataSource remoteDataSource,
    required MedicationNotificationService notificationService,
  }) : _firestore = firestore,
       _storage = storage,
       _localDataSource = localDataSource,
       _remoteDataSource = remoteDataSource,
       _notificationService = notificationService;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final MedicationLocalDataSource _localDataSource;
  final MedicationRemoteDataSource _remoteDataSource;
  final MedicationNotificationService _notificationService;
  Future<void>? _syncInFlight;

  void queueBackupAndSync({required String uid}) {
    unawaited(
      backupAndSync(uid: uid).catchError((Object error, StackTrace stackTrace) {
        debugPrint('Medication sync deferred: $error');
        debugPrintStack(stackTrace: stackTrace);
      }),
    );
  }

  void queuePush({
    required String uid,
    required Medication medication,
    required SyncOperation operation,
  }) {
    unawaited(_push(uid: uid, medication: medication, operation: operation));
  }

  Future<void> _push({
    required String uid,
    required Medication medication,
    required SyncOperation operation,
  }) async {
    try {
      switch (operation) {
        case SyncOperation.upsert:
          await _remoteDataSource.upsertMedication(
            uid: uid,
            medication: medication,
          );
        case SyncOperation.delete:
          await _remoteDataSource.deleteMedication(medication.id);
          await _localDataSource.clearPendingDeletion(medication.id);
      }
    } catch (error, stackTrace) {
      debugPrint('Medication sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> syncFromCloud({required String uid}) async {
    final remoteMedications = await _remoteDataSource.fetchForUser(uid);
    await _localDataSource.replaceAll(remoteMedications);
    await _notificationService.rescheduleAll(remoteMedications);
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
    await ref.putData(fileBytes).timeout(const Duration(seconds: 30));
    return ref.getDownloadURL().timeout(const Duration(seconds: 20));
  }

  Future<void> backupLocalToCloud({required String uid}) async {
    final pendingDeletionIds = await _localDataSource.getPendingDeletionIds();
    for (final id in pendingDeletionIds) {
      await _remoteDataSource
          .deleteMedication(id)
          .timeout(const Duration(seconds: 20));
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

  Future<void> ensureSyncedOnLogin({required String uid}) async {
    await _firestore.enableNetwork();
    await backupAndSync(uid: uid);
  }

  Future<void> backupAndSync({required String uid}) async {
    final running = _syncInFlight;
    if (running != null) {
      return running;
    }

    late final Future<void> operation;
    operation = _backupAndSync(uid).whenComplete(() {
      if (identical(_syncInFlight, operation)) {
        _syncInFlight = null;
      }
    });
    _syncInFlight = operation;
    return operation;
  }

  Future<void> _backupAndSync(String uid) async {
    await _firestore.enableNetwork();
    await backupLocalToCloud(uid: uid);
    await syncFromCloud(uid: uid);
  }
}

enum SyncOperation { upsert, delete }
