import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/firestore_collections.dart';
import '../../domain/models/medication.dart';

class MedicationRemoteDataSource {
  MedicationRemoteDataSource({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _remindersFor(String uid) =>
      _firestore
          .collection(FirestoreCollections.users)
          .doc(uid)
          .collection(FirestoreCollections.reminders);

  Future<List<Medication>> getAll({required String uid}) async {
    final snapshot = await _remindersFor(uid).get();
    final medications = <Medication>[];
    for (final document in snapshot.docs) {
      try {
        medications.add(Medication.fromFirestore(document));
      } catch (error) {
        debugPrint('Skipping malformed cloud reminder ${document.id}: $error');
      }
    }
    return medications;
  }

  Future<void> upsertMedication({
    required String uid,
    required Medication medication,
  }) async {
    await _remindersFor(uid)
        .doc(medication.id)
        .set(medication.toFirestore(uid: uid), SetOptions(merge: true));
  }

  Future<void> deleteMedication({
    required String uid,
    required String id,
  }) async {
    await _remindersFor(uid).doc(id).delete();
  }
}
