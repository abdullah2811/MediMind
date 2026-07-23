import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

abstract class AppLanguagePreferenceStore {
  Future<String?> read();
  Future<void> write(String languageCode);
}

class HiveAppLanguagePreferenceStore implements AppLanguagePreferenceStore {
  static const _boxName = 'user_language_preferences';
  static const _devicePreferenceKey = 'device_language';

  @override
  Future<String?> read() async {
    try {
      final box = await Hive.openBox<String>(_boxName);
      final devicePreference = box.get(_devicePreferenceKey);
      if (devicePreference == 'en' || devicePreference == 'bn') {
        return devicePreference;
      }
      final legacyPreference = box.values.cast<String?>().lastWhere(
        (value) => value == 'en' || value == 'bn',
        orElse: () => null,
      );
      if (legacyPreference != null) {
        await box.put(_devicePreferenceKey, legacyPreference);
      }
      return legacyPreference;
    } catch (error) {
      debugPrint('Could not read language preference: $error');
      return null;
    }
  }

  @override
  Future<void> write(String languageCode) async {
    try {
      final box = await Hive.openBox<String>(_boxName);
      await box.put(_devicePreferenceKey, languageCode);
    } catch (error) {
      debugPrint('Could not save language preference: $error');
    }
  }
}
