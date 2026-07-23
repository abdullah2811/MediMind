import 'package:hive/hive.dart';

import '../../domain/models/medication.dart';

class MedicationLocalDataSource {
  MedicationLocalDataSource({required this.boxName});

  final String boxName;

  final Map<String, Future<Box<dynamic>>> _userBoxes =
      <String, Future<Box<dynamic>>>{};
  static const _deletedKeyPrefix = '__pending_delete__:';
  static const _legacyMigrationOwnerKey = 'legacy_migration_owner';

  Future<Box<dynamic>> _openBox(String uid) {
    if (uid.isEmpty) {
      throw ArgumentError.value(uid, 'uid', 'User ID must not be empty.');
    }
    return _userBoxes.putIfAbsent(uid, () => _openUserBox(uid));
  }

  Future<Box<dynamic>> _openUserBox(String uid) async {
    final safeUid = uid.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final box = await Hive.openBox<dynamic>('${boxName}_$safeUid');
    final metadata = await Hive.openBox<dynamic>('${boxName}_metadata');
    if (metadata.get(_legacyMigrationOwnerKey) == null) {
      final legacy = await Hive.openBox<dynamic>(boxName);
      if (box.isEmpty && legacy.isNotEmpty) {
        await box.putAll(legacy.toMap());
      }
      await metadata.put(_legacyMigrationOwnerKey, uid);
    }
    return box;
  }

  Future<List<Medication>> getAll({required String uid}) async {
    final box = await _openBox(uid);
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

  Future<Medication?> getById({required String uid, required String id}) async {
    final box = await _openBox(uid);
    final value = box.get(id);
    if (value == null) {
      return null;
    }
    return Medication.fromJson(Map<String, dynamic>.from(value as Map));
  }

  Future<void> save({
    required String uid,
    required Medication medication,
  }) async {
    final box = await _openBox(uid);
    await box.put(medication.id, medication.toJson());
    await box.delete('$_deletedKeyPrefix${medication.id}');
  }

  Future<void> delete({required String uid, required String id}) async {
    final box = await _openBox(uid);
    await box.delete(id);
    await box.put('$_deletedKeyPrefix$id', true);
  }

  Future<List<String>> getPendingDeletionIds({required String uid}) async {
    final box = await _openBox(uid);
    return box.keys
        .map((key) => key.toString())
        .where((key) => key.startsWith(_deletedKeyPrefix))
        .map((key) => key.substring(_deletedKeyPrefix.length))
        .toList(growable: false);
  }

  Future<void> clearPendingDeletion({
    required String uid,
    required String id,
  }) async {
    final box = await _openBox(uid);
    await box.delete('$_deletedKeyPrefix$id');
  }

  Future<void> replaceAll({
    required String uid,
    required List<Medication> medications,
  }) async {
    final box = await _openBox(uid);
    final pendingDeletionIds = await getPendingDeletionIds(uid: uid);
    await box.clear();
    for (final medication in medications) {
      await box.put(medication.id, medication.toJson());
    }
    for (final id in pendingDeletionIds) {
      await box.put('$_deletedKeyPrefix$id', true);
    }
  }
}
