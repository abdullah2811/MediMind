import 'package:flutter_test/flutter_test.dart';
import 'package:medimind/core/config/firebase_auth_environment.dart';

void main() {
  group('resolveFirebaseAuthTesting', () {
    test('enables testing only when both debug and requested', () {
      expect(
        resolveFirebaseAuthTesting(isDebugBuild: true, testingRequested: true),
        isTrue,
      );
    });

    test('keeps testing disabled in release when requested', () {
      expect(
        resolveFirebaseAuthTesting(isDebugBuild: false, testingRequested: true),
        isFalse,
      );
    });

    test('keeps testing disabled by default in debug', () {
      expect(
        resolveFirebaseAuthTesting(isDebugBuild: true, testingRequested: false),
        isFalse,
      );
    });

    test('keeps testing disabled in release by default', () {
      expect(
        resolveFirebaseAuthTesting(
          isDebugBuild: false,
          testingRequested: false,
        ),
        isFalse,
      );
    });
  });
}
