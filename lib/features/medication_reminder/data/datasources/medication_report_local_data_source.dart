import 'package:hive/hive.dart';

import '../../domain/models/medication_report.dart';

class MedicationReportLocalDataSource {
  MedicationReportLocalDataSource({required this.boxName});

  final String boxName;
  Box<dynamic>? _box;

  Future<Box<dynamic>> _openBox() async {
    _box ??= await Hive.openBox<dynamic>(boxName);
    return _box!;
  }

  String _key(String uid, int rangeDays) => '$uid:last_${rangeDays}_days';

  Future<MedicationReport?> get({
    required String uid,
    required int rangeDays,
  }) async {
    final box = await _openBox();
    final value = box.get(_key(uid, rangeDays));
    if (value == null) {
      return null;
    }
    return MedicationReport.fromJson(Map<String, dynamic>.from(value as Map));
  }

  Future<List<MedicationReport>> getAll({required String uid}) async {
    final box = await _openBox();
    final prefix = '$uid:';
    return box
        .toMap()
        .entries
        .where((entry) => entry.key.toString().startsWith(prefix))
        .map(
          (entry) => MedicationReport.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<void> save({
    required String uid,
    required MedicationReport report,
  }) async {
    final box = await _openBox();
    await box.put(_key(uid, report.rangeDays), report.toJson());
  }
}
