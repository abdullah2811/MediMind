import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firestore_collections.dart';
import '../../domain/models/medication_report.dart';

class MedicationReportRemoteDataSource {
  MedicationReportRemoteDataSource({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _reportsFor(String uid) =>
      _firestore
          .collection(FirestoreCollections.users)
          .doc(uid)
          .collection(FirestoreCollections.reports);

  Future<void> upsertReport({
    required String uid,
    required MedicationReport report,
  }) async {
    await _reportsFor(uid).doc(report.id).set(report.toFirestore(uid: uid));
  }
}
