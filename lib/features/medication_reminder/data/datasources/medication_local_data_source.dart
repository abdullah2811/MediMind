import 'package:hive/hive.dart';

import '../../domain/models/medication.dart';

class MedicationLocalDataSource {
  MedicationLocalDataSource({required this.boxName});

  final String boxName;

  Box<dynamic>? _box;

  Future<Box<dynamic>> _openBox() async {
    _box ??= await Hive.openBox<dynamic>(boxName);
    return _box!;
  }

  Future<List<Medication>> getAll() async {
    final box = await _openBox();
    return box.values
        .map(
          (value) =>
              Medication.fromJson(Map<String, dynamic>.from(value as Map)),
        )
        .toList(growable: false);
  }

  Future<Medication?> getById(String id) async {
    final box = await _openBox();
    final value = box.get(id);
    if (value == null) {
      return null;
    }
    return Medication.fromJson(Map<String, dynamic>.from(value as Map));
  }

  Future<void> save(Medication medication) async {
    final box = await _openBox();
    await box.put(medication.id, medication.toJson());
  }

  Future<void> delete(String id) async {
    final box = await _openBox();
    await box.delete(id);
  }

  Future<void> replaceAll(List<Medication> medications) async {
    final box = await _openBox();
    await box.clear();
    for (final medication in medications) {
      await box.put(medication.id, medication.toJson());
    }
  }
}
