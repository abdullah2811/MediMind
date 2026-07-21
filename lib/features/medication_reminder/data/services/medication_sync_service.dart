import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../datasources/medication_local_data_source.dart';
import '../datasources/medication_remote_data_source.dart';
import '../../domain/models/medication.dart';

class MedicationSyncService {
  MedicationSyncService({
    required FirebaseFirestore firestore,
    required FirebaseStorage storage,
    required MedicationLocalDataSource localDataSource,
    required MedicationRemoteDataSource remoteDataSource,
  }) : _firestore = firestore,
       _storage = storage,
       _localDataSource = localDataSource,
       _remoteDataSource = remoteDataSource;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final MedicationLocalDataSource _localDataSource;
  final MedicationRemoteDataSource _remoteDataSource;
  Future<void>? _backupInFlight;

  void queueBackup({required String uid}) {
    unawaited(
      backup(uid: uid).catchError((Object error, StackTrace stackTrace) {
        debugPrint('Medication backup deferred: $error');
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
          await _remoteDataSource.deleteMedication(uid: uid, id: medication.id);
          await _localDataSource.clearPendingDeletion(medication.id);
      }
    } catch (error, stackTrace) {
      debugPrint('Medication sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
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

  Future<void> backup({required String uid}) async {
    final running = _backupInFlight;
    if (running != null) {
      return running;
    }

    late final Future<void> operation;
    operation = _backup(uid).whenComplete(() {
      if (identical(_backupInFlight, operation)) {
        _backupInFlight = null;
      }
    });
    _backupInFlight = operation;
    return operation;
  }

  Future<void> _backup(String uid) async {
    await _firestore.enableNetwork();
    await backupLocalToCloud(uid: uid);
  }
}

enum SyncOperation { upsert, delete }
