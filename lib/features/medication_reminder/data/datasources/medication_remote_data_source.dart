import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firestore_collections.dart';
import '../../domain/models/medication.dart';

class MedicationRemoteDataSource {
  MedicationRemoteDataSource({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _reminders =>
      _firestore.collection(FirestoreCollections.reminders);

  Future<void> upsertMedication({
    required String uid,
    required Medication medication,
  }) async {
    await _reminders
        .doc(medication.id)
        .set(medication.toFirestore(uid: uid), SetOptions(merge: true));
  }

  Future<void> deleteMedication(String id) async {
    await _reminders.doc(id).delete();
  }
}
