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
    await ref.putData(fileBytes);
    return ref.getDownloadURL();
  }

  Future<void> backupLocalToCloud({required String uid}) async {
    final localMedications = await _localDataSource.getAll();
    for (final medication in localMedications) {
      final cloudImageUrl = await _uploadMedicationImageIfNeeded(
        userId: uid,
        medication: medication,
      );
      await _remoteDataSource.upsertMedication(
        uid: uid,
        medication: medication.copyWith(backupImageUrl: cloudImageUrl),
      );
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
    await syncFromCloud(uid: uid);
  }
}

enum SyncOperation { upsert, delete }
