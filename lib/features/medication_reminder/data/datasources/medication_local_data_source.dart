import 'package:hive/hive.dart';

import '../../domain/models/medication.dart';

class MedicationLocalDataSource {
  MedicationLocalDataSource({required this.boxName});

  final String boxName;

  Box<dynamic>? _box;
  static const _deletedKeyPrefix = '__pending_delete__:';

  Future<Box<dynamic>> _openBox() async {
    _box ??= await Hive.openBox<dynamic>(boxName);
    return _box!;
  }

  Future<List<Medication>> getAll() async {
    final box = await _openBox();
    return box
        .toMap()
        .entries
        .where((entry) => !entry.key.toString().startsWith(_deletedKeyPrefix))
        .map(
          (entry) => Medication.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          ),
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
    await box.delete('$_deletedKeyPrefix${medication.id}');
  }

  Future<void> delete(String id) async {
    final box = await _openBox();
    await box.delete(id);
    await box.put('$_deletedKeyPrefix$id', true);
  }

  Future<List<String>> getPendingDeletionIds() async {
    final box = await _openBox();
    return box.keys
        .map((key) => key.toString())
        .where((key) => key.startsWith(_deletedKeyPrefix))
        .map((key) => key.substring(_deletedKeyPrefix.length))
        .toList(growable: false);
  }

  Future<void> clearPendingDeletion(String id) async {
    final box = await _openBox();
    await box.delete('$_deletedKeyPrefix$id');
  }

  Future<void> replaceAll(List<Medication> medications) async {
    final box = await _openBox();
    final pendingDeletionIds = await getPendingDeletionIds();
    await box.clear();
    for (final medication in medications) {
      await box.put(medication.id, medication.toJson());
    }
    for (final id in pendingDeletionIds) {
      await box.put('$_deletedKeyPrefix$id', true);
    }
  }
}
