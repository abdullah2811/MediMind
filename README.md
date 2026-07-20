# MediMind

A Flutter medication reminder app using Firebase Authentication, Firestore,
and Storage.

## Firebase authentication setup

Enable the Phone and Google providers in the Firebase Console. For real SMS,
enable Bangladesh in the SMS region policy and use an eligible billing plan.
Production web domains must be listed under Authentication > Settings >
Authorized domains.

### Debug with Firebase test phone numbers

In Firebase Console > Authentication > Sign-in method > Phone, add a fictional
test phone number and a fixed six-digit code. Then run:

```powershell
flutter pub get
flutter run -d chrome --dart-define=FIREBASE_AUTH_TESTING=true
```

This flag disables app verification only when Flutter is running a debug build.
Only Firebase-configured test phone numbers work in this mode.

### Debug with real Firebase verification

Omit the test flag:

```powershell
flutter run -d chrome
```

Real web phone verification uses Firebase reCAPTCHA and should be tested from a
deployed, authorized HTTPS domain. Repeated failed requests may be throttled by
Firebase.

### Release

Build without the test flag:

```powershell
flutter build web --release
```

The app also checks `kDebugMode`, so app verification remains enabled in
release builds even if `FIREBASE_AUTH_TESTING=true` is accidentally supplied.
