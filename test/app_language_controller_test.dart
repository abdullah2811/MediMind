import 'package:flutter_test/flutter_test.dart';
import 'package:medimind/core/localization/app_language_preference_store.dart';
import 'package:medimind/core/localization/app_localization.dart';

class _MemoryLanguageStore implements AppLanguagePreferenceStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String uid) async => values[uid];

  @override
  Future<void> write(String uid, String languageCode) async {
    values[uid] = languageCode;
  }
}

void main() {
  test('language choice is restored independently for each user', () async {
    final store = _MemoryLanguageStore();
    final controller = AppLanguageController(preferenceStore: store);

    await controller.bindUser('user-a');
    controller.setLanguage('en');
    await Future<void>.delayed(Duration.zero);
    await controller.bindUser(null);
    expect(controller.languageCode, 'bn');

    await controller.bindUser('user-a');
    expect(controller.languageCode, 'en');
  });
}
