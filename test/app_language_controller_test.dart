import 'package:flutter_test/flutter_test.dart';
import 'package:medimind/core/localization/app_language_preference_store.dart';
import 'package:medimind/core/localization/app_localization.dart';

class _MemoryLanguageStore implements AppLanguagePreferenceStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String languageCode) async => value = languageCode;
}

void main() {
  test('language choice is restored for the device across sessions', () async {
    final store = _MemoryLanguageStore();
    final firstSession = AppLanguageController(preferenceStore: store);

    await firstSession.restore();
    firstSession.setLanguage('en');
    await Future<void>.delayed(Duration.zero);

    final signedOutSession = AppLanguageController(preferenceStore: store);
    await signedOutSession.restore();
    expect(signedOutSession.languageCode, 'en');

    final nextLoginSession = AppLanguageController(preferenceStore: store);
    await nextLoginSession.restore();
    expect(nextLoginSession.languageCode, 'en');
  });
}
