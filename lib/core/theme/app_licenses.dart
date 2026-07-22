import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

void registerAppLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const <String>[
      'Manrope',
    ], await rootBundle.loadString('assets/fonts/Manrope-OFL.txt'));
  });
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const <String>[
      'Noto Sans Bengali',
    ], await rootBundle.loadString('assets/fonts/NotoSansBengali-OFL.txt'));
  });
}
