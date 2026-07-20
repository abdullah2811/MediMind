import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

const bool firebaseAuthTestingRequested = bool.fromEnvironment(
  'FIREBASE_AUTH_TESTING',
);

bool resolveFirebaseAuthTesting({
  required bool isDebugBuild,
  required bool testingRequested,
}) {
  return isDebugBuild && testingRequested;
}

bool get firebaseAuthTestingEnabled => resolveFirebaseAuthTesting(
  isDebugBuild: kDebugMode,
  testingRequested: firebaseAuthTestingRequested,
);

Future<void> configureFirebaseAuthForEnvironment(FirebaseAuth auth) async {
  if (!firebaseAuthTestingEnabled) {
    return;
  }

  await auth.setSettings(appVerificationDisabledForTesting: true);
  debugPrint(
    'Firebase phone auth test mode is enabled. '
    'Only Firebase-configured test phone numbers will work.',
  );
}
