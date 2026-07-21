import 'package:hive_flutter/hive_flutter.dart';

const mobileSessionInactivityLimit = Duration(days: 30);

bool isMobileSessionExpired({
  required DateTime? lastActivity,
  required DateTime now,
}) {
  if (lastActivity == null) {
    return false;
  }
  return now.difference(lastActivity) >= mobileSessionInactivityLimit;
}

abstract class SessionActivityStore {
  Future<DateTime?> readLastActivity(String uid);

  Future<void> writeLastActivity(String uid, DateTime time);

  Future<void> clear(String uid);
}

class HiveSessionActivityStore implements SessionActivityStore {
  HiveSessionActivityStore({this.boxName = 'session_activity'});

  final String boxName;

  Future<Box<String>> _openBox() => Hive.openBox<String>(boxName);

  @override
  Future<DateTime?> readLastActivity(String uid) async {
    final box = await _openBox();
    final storedValue = box.get(uid);
    return storedValue == null ? null : DateTime.tryParse(storedValue);
  }

  @override
  Future<void> writeLastActivity(String uid, DateTime time) async {
    final box = await _openBox();
    await box.put(uid, time.toUtc().toIso8601String());
  }

  @override
  Future<void> clear(String uid) async {
    final box = await _openBox();
    await box.delete(uid);
  }
}
