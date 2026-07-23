import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

abstract class AppLanguagePreferenceStore {
  Future<String?> read(String uid);
  Future<void> write(String uid, String languageCode);
}

class HiveAppLanguagePreferenceStore implements AppLanguagePreferenceStore {
  static const _boxName = 'user_language_preferences';

  @override
  Future<String?> read(String uid) async {
    try {
      final box = await Hive.openBox<String>(_boxName);
      return box.get(uid);
    } catch (error) {
      debugPrint('Could not read language preference: $error');
      return null;
    }
  }

  @override
  Future<void> write(String uid, String languageCode) async {
    try {
      final box = await Hive.openBox<String>(_boxName);
      await box.put(uid, languageCode);
    } catch (error) {
      debugPrint('Could not save language preference: $error');
    }
  }
}
