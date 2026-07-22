# MediMind

MediMind is a bilingual medication reminder application built with Flutter and
Firebase. It is designed for users in Bangladesh, works with or without an
active internet connection. The device database is the source of truth, while
Firebase is used only as an online backup when connectivity is available.

The application currently targets Android, iOS, and the web.

## Main features

- Phone-number sign-in and Google/Gmail sign-in only.
- Flexible Bangladesh phone-number entry.
- Automatic conversion of valid numbers to Firebase-compatible E.164 format.
- Bengali and English interfaces, with Bengali selected by default.
- Medicine type selection: tablet, capsule, syrup, drop, or insulin.
- Medicine strength entry with units such as mg, g, and mcg.
- Multiple daily medicine times, each with its own dosage.
- Repeat schedules for daily, weekly, every 15 days, monthly, or a custom
  interval from 1 to 365 days.
- Dosage units derived automatically from the medicine type.
- Optional meal reminders calculated from the medicine reminder time.
- Custom before-meal and after-meal offsets, defaulting to 20 minutes.
- Medicine and meal taken/not-taken tracking, including the actual time and
  whether a late dose was taken with food.
- Optional medicine photos shown prominently on dashboard cards and Android
  notifications.
- High-priority local notifications in the language used when the
  medicine was saved, with Android actions for recording medicine and meal
  taken/not-taken status without opening the app.
- Collision-safe reminder planning that merges events scheduled for the same
  minute and rejects contradictory nearby meal anchors.
- A dashboard showing the next medicine/meal events in chronological order,
  beginning at the top-right of the hero card, with weekday/date headings,
  the live current time, and a dynamic day-cycle arc whose event dots change
  after their times pass.
- Detailed local-first 7-day and 30-day reports with scheduled times, actual
  medicine/meal times, taken/not-taken status, and owner-only cloud snapshots.
- Local-first storage using Hive.
- Automatic Firebase backup after medicines are added or updated.
- Automatic backup retry when network connectivity returns.
- Persistent offline deletion records so cloud backups reflect local deletes.
- Manual backup controls when medicines exist.
- Persistent mobile sign-in with automatic sign-out after 30 days of
  inactivity.
- Responsive layouts for narrow phone screens and wider web screens.

## Technology stack

| Area | Technology |
| --- | --- |
| UI | Flutter and Material 3 |
| Authentication | Firebase Authentication |
| Cloud database | Cloud Firestore |
| Photo backup | Firebase Storage |
| Local database | Hive |
| Notifications | flutter_local_notifications |
| Connectivity monitoring | connectivity_plus |
| Google sign-in | google_sign_in |
| Image capture | image_picker |
| Time-zone scheduling | timezone, configured for Asia/Dhaka |
| Localization | Custom English and Bengali localization scope |
| Typography | Bundled Manrope and Noto Sans Bengali fonts |

## Project structure

```text
lib/
  app.dart                         Application composition and dependencies
  firebase_options.dart            Generated Firebase platform configuration
  core/
    config/                         Environment-specific Firebase behavior
    constants/                      Firestore collection names
    localization/                   English and Bengali text and language state
    theme/                          Colors, typography, and font licenses
  features/
    auth/
      data/                         Firebase authentication implementation
      domain/                       Authentication contracts and phone parsing
      presentation/                 Login and phone verification screens
    medication_reminder/
      data/
        datasources/                Hive and Firebase data access
        repositories/               Local-first repository implementation
        services/                   Notifications and synchronization
      domain/                       Medication model and repository contract
      presentation/                 Dashboard and medicine form
assets/fonts/                       Bundled fonts and license files
test/                               Unit and widget tests
android/                            Android runner and configuration
ios/                                iOS runner and configuration
web/                                Web entry point, manifest, and icons
```

## Prerequisites

Install the following before running the project:

1. Flutter with a Dart SDK compatible with `^3.9.0`.
2. Android Studio and an Android SDK for Android development.
3. Xcode and CocoaPods on macOS for iOS development.
4. Chrome or another supported browser for Flutter web development.
5. A Firebase project with Authentication, Firestore, and Storage enabled.
6. The FlutterFire CLI if the Firebase configuration must be regenerated.
7. The Firebase CLI if the web build will be deployed to Firebase Hosting.

Verify the local development environment:

```powershell
flutter doctor
flutter devices
```

## Initial setup

From the project directory, install dependencies:

```powershell
flutter pub get
```

The repository currently contains Firebase configuration for the project shown
in `firebase.json` and `lib/firebase_options.dart`. To use another Firebase
project, sign in to the Firebase CLI and regenerate the configuration:

```powershell
firebase login
dart pub global activate flutterfire_cli
flutterfire configure
```

Select Android, iOS, and Web when prompted. Confirm that these platform files
are present or generated correctly:

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`, when required by the iOS setup

Do not copy credentials from an unrelated Firebase project. Firebase client
API keys identify the project but do not replace proper Authentication,
Firestore, and Storage security rules.

## Firebase Authentication configuration

Open Firebase Console, select the project, and go to **Authentication >
Sign-in method**.

### Phone authentication

1. Enable the Phone provider.
2. Open the SMS region policy and allow Bangladesh.
3. Use a Firebase billing plan that supports real verification SMS in the
   target region.
4. Add fictional test numbers for development and automated manual testing.
5. For web builds, add every development and production hostname under
   **Authentication > Settings > Authorized domains**.
6. For Android, register the application SHA-1 and SHA-256 fingerprints in the
   Firebase project settings.

The app accepts common Bangladesh mobile-number formats and normalizes them
before sending them to Firebase. Examples include:

```text
+8801712345678
8801712345678
008801712345678
01712345678
1712345678
01712-345678
```

Spaces, parentheses, hyphens, and Bengali digits are also accepted. A valid
number is stored and sent to Firebase as `+8801XXXXXXXXX`.

### Google/Gmail authentication

1. Enable the Google provider in Firebase Authentication.
2. Select a support email for the provider.
3. Register Android SHA fingerprints.
4. Complete the iOS URL scheme and reversed client ID configuration if running
   on iOS.
5. Add web deployment domains to the authorized-domain list.

## Debug phone authentication

### Recommended: Firebase test phone numbers

In Firebase Console, add a fictional test phone number and a fixed six-digit
verification code. Then run the application with:

```powershell
flutter run -d chrome --dart-define=FIREBASE_AUTH_TESTING=true
```

This mode disables app verification only when both conditions are true:

- Flutter is running a debug build.
- `FIREBASE_AUTH_TESTING=true` was explicitly supplied.

Only test phone numbers configured in Firebase will work in this mode. Do not
use real phone numbers while app verification is disabled.

### Real Firebase verification in a debug build

Omit the testing flag:

```powershell
flutter run -d chrome
```

Real web phone authentication uses Firebase reCAPTCHA. The visible badge is
hidden by the web stylesheet, while the required Google Privacy Policy and
Terms of Service disclosure remains visible on the phone sign-in screen.
Firebase may still display a reCAPTCHA challenge when a request requires
additional verification.

For realistic web testing, use an authorized HTTPS domain. Repeated failed
requests can trigger Firebase throttling even in a development environment.

## Firestore configuration

The application stores each user's medicine documents under:

```text
users/{userId}/reminders/{reminderId}
users/{userId}/reports/{reportId}
```

The checked-in `firestore.rules` file only permits the authenticated owner to
access those paths and validates the owner and document identifiers. Report
documents are restricted to the supported 7-day and 30-day ranges.
The path-scoped design also permits safe deletion of a backup that does not yet
exist without allowing one user to delete another user's data.

## Firebase Storage configuration

Medicine photos are uploaded to:

```text
medication_images/{userId}/{medicineId}.jpg
```

The checked-in `storage.rules` file permits owner-only access and restricts
uploads to images smaller than 10 MB.

Photos are optional and are used only as a visual identification aid. The
compressed image bytes are stored with the local Hive medicine record so the
dashboard and notification scheduler do not depend on internet access. During
backup, the image file is uploaded to Firebase Storage and Firestore stores its
download URL in the corresponding reminder document; Firestore does not store
the image bytes themselves. Replacing a photo uploads the new image, and
deleting a medicine removes its predictable Storage object during the next
successful backup.

Deploy both rulesets after signing in to the Firebase CLI:

```powershell
firebase login
firebase deploy --only firestore:rules --project medimind-368ed
firebase deploy --only storage --project medimind-368ed
```

The rule files are connected to those commands through `firebase.json`. If the
CLI is unavailable, copy `firestore.rules` into **Firestore Database > Rules**
and `storage.rules` into **Storage > Rules** in Firebase Console, then publish
each ruleset.

## Platform permissions

### Android

The Android application needs internet access in release builds. Confirm that
the following permission is present in
`android/app/src/main/AndroidManifest.xml`, not only in the debug or profile
manifest:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

The main manifest declares notification, vibration, exact-alarm, reboot, and
full-screen-intent permissions. It also registers the scheduled-notification
action, and reboot receivers required by `flutter_local_notifications`. The app asks
for notification, exact-alarm, and full-screen-intent access where supported.
Review current Google Play policy requirements before publishing an application
that requests exact alarms or full-screen intents.

### iOS

The medicine form can open the camera through `image_picker`. Add a camera usage
description to `ios/Runner/Info.plist` before testing photo capture on iOS:

```xml
<key>NSCameraUsageDescription</key>
<string>MediMind uses the camera to attach a photo to a medicine.</string>
```

If photo-library selection is added later, also add the appropriate photo
library usage description. Notification permissions are requested by the app
at runtime.

## Offline storage and synchronization

MediMind follows a strict local-first workflow. Hive is always the source of
truth; automatic synchronization never replaces local data with cloud data.

1. A medicine is saved to Hive immediately.
2. Local notifications are scheduled immediately.
3. A cloud backup is requested in the background.
4. If the device is offline, the local record remains available and usable.
5. Connectivity changes are monitored while the signed-in dashboard is open.
6. Rolling 7-day and 30-day report snapshots are generated and stored in a
   separate Hive box from the same local check-in history.
7. When a network connection becomes available, local medicines, reports, and
   pending deletions are uploaded to the user's cloud backup.

The dashboard checks periodically for pending synchronization while a network
connection is reported. Actual uploads are serialized into one operation.
Transient failures use an increasing cooldown, while Firestore
`permission-denied` and internal-client assertion errors pause automatic cloud
attempts for the signed-in session. This prevents a broken cloud configuration
from creating a retry storm; local data and reminders continue to work.

Offline deletions are stored as local tombstones. They are sent to Firestore
before the next backup upload so the online backup matches the local database.
Report entries already recorded within their time range are retained even if a
medicine is later deleted.

The manual **Backup** button remains available when at least one medicine
exists. If manual backup fails because the device is offline, the app confirms
that the data is saved locally and will be retried later.

## Medication and reminder behavior

Each medicine can include:

- Name.
- Type: tablet, capsule, syrup, drop, or insulin.
- Strength value and unit.
- Optional generic name or formula.
- Optional company name.
- Optional notes.
- Optional photo.
- One or more medicine reminder times.
- A dosage value for every reminder time.
- A repeat schedule: daily, weekly, every 15 days, monthly, or a custom number
  of days.
- An optional meal-time relationship.

Dosage units are selected automatically:

| Medicine type | Dosage unit |
| --- | --- |
| Tablet | Pill |
| Capsule | Pill |
| Syrup | Millilitre |
| Drop | Drop |
| Insulin | Units |

Medicine reminders are always enabled. The optional meal reminder can be
enabled or disabled separately.

Meal times are calculated from the medicine time:

| Selection | Calculation example |
| --- | --- |
| 20 minutes before a meal | Medicine at 09:00, meal at 09:20 |
| With the meal | Medicine at 09:00, meal at 09:00 |
| 20 minutes after a meal | Medicine at 09:00, meal at 08:40 |

Meal-linked reminders within the same one-hour meal window must resolve to one
meal time. Exact matches are accepted and combined into one meal notification.
Contradictory times are rejected before saving, and the form shows the corrected
medicine time. For example, if an existing 09:00 PM medicine is 20 minutes
before a 09:20 PM meal, a new medicine taken 30 minutes after that meal must be
set to 09:50 PM. A proposed 09:30 PM time would imply a conflicting 09:00 PM
meal and is therefore not saved.

Monthly schedules preserve the starting day where possible and use the final
day of shorter months. Custom intervals accept whole numbers from 1 through
365. Reminder occurrences are stored locally as part of the medicine record;
Firebase remains the backup rather than the source of truth.

Notifications use the `Asia/Dhaka` time zone. Android users may be asked to
allow notifications, exact alarms, and full-screen alarms. Scheduled Android
notifications are restored after a device reboot. iOS notifications use the
Time Sensitive interruption level and may ask users to allow alert, badge, and
sound permissions. Clock controls and displayed reminder times use a 12-hour
format.

Android medicine-only and meal-only reminders provide taken/not-taken action
buttons. When a medicine and meal share one reminder minute, Android shows
**All taken** and **None taken** so the single merged notification remains
unambiguous. These actions update Hive and local reports in a background
workflow: Android first persists the action while the app is sleeping, then
MediMind applies it to Hive and local reports when the app starts or resumes.
The result is uploaded during the next successful backup. Notification action
buttons are not available in the web build.

When a local medicine photo exists, Android uses it as the notification's large
icon and shows it as expanded artwork for a single-medicine reminder. If a
merged reminder contains several medicines, one available photo is kept as the
compact large icon while the text lists every affected medicine.

## Reports

Open reports from the chart icon in the dashboard app bar. Each report has a
fixed, visible period: the current calendar day plus the preceding 6 or 29
calendar days. Reports are rebuilt from local check-ins, so opening and reading
them never depends on internet access.

Each entry includes the medicine name and dosage, scheduled dose time,
medicine taken/not-taken status, actual medicine time, meal taken/not-taken
status, actual meal time, and whether the medicine was taken with food. The two
rolling snapshots are mirrored to Firestore at:

```text
users/{userId}/reports/last_7_days
users/{userId}/reports/last_30_days
```

## Localization and design

- Bengali is the default application language.
- English can be selected from the segmented language control on the login
  screen.
- The brand name is always displayed as `MediMind`.
- Medicine notifications use the language active when the medicine was saved.
- Manrope is bundled for English and branding.
- Noto Sans Bengali is bundled for Bengali text.
- Both fonts work without downloading font files at runtime.

The font files are distributed under the SIL Open Font License. Their license
texts are included in `assets/fonts` and registered with Flutter's application
license registry.

## Running the application

List available devices:

```powershell
flutter devices
```

Run on Chrome:

```powershell
flutter run -d chrome
```

Run using Flutter's web server:

```powershell
flutter run -d web-server --web-port 7357
```

Run on a connected Android device or emulator:

```powershell
flutter run -d <android-device-id>
```

Run on an iOS simulator or device from macOS:

```powershell
flutter run -d <ios-device-id>
```

## Code quality and tests

Format the source code:

```powershell
dart format lib test
```

Run static analysis:

```powershell
flutter analyze
```

Run all tests:

```powershell
flutter test
```

The test suite covers:

- Bangladesh phone-number normalization.
- Debug and release Firebase test-mode safeguards.
- Medication serialization and legacy-data compatibility.
- All recurrence rules and date-specific notification planning.
- Ordered dashboard event sequencing for medicine and meal reminders.
- Local report ranges, detailed actual-time entries, and retained history.
- Meal-time calculation and contradictory meal-window prevention.
- Offline deletion persistence.
- Bengali-first login and language switching.
- Empty and non-empty dashboard button states.
- Responsive medicine-form behavior on narrow screens.

Recommended pre-commit verification:

```powershell
dart format lib test
flutter analyze
flutter test
flutter build web --release
```

## Release builds

### Web

Build without the Firebase testing flag:

```powershell
flutter build web --release
```

The output is written to `build/web`. Deploy that directory to an HTTPS host,
then add the production domain to Firebase Authentication's authorized domains.

The application checks Flutter's release mode in addition to the Dart define.
App verification therefore remains enabled in release builds even if
`FIREBASE_AUTH_TESTING=true` is supplied accidentally.

### Android

Build an Android App Bundle for Play Console distribution:

```powershell
flutter build appbundle --release
```

Build a release APK for direct installation:

```powershell
flutter build apk --release
```

Configure a private release signing key before publishing. Do not commit the
keystore or its passwords.

### iOS

From macOS, build an archive suitable for App Store distribution:

```powershell
flutter build ipa --release
```

Configure the Apple signing team, bundle identifier, capabilities, and Firebase
iOS settings in Xcode before publishing.

## Troubleshooting

### `invalid-app-credential` or `captcha-check-failed`

- Confirm that the current web hostname is an authorized Firebase domain.
- Refresh the page so Firebase can create a new reCAPTCHA token.
- Do not reuse an expired verification session.
- Test real verification from an authorized HTTPS deployment.
- Use Firebase-configured test phone numbers during local development.

### `too-many-requests`

Firebase temporarily blocks repeated suspicious requests by device, IP address,
phone number, or project. Stop retrying, wait for the block to expire, and use a
configured fictional test number for development.

### No verification SMS arrives

- Confirm that Phone authentication is enabled.
- Confirm that Bangladesh is allowed in the SMS region policy.
- Confirm that Firebase billing and SMS quota are available.
- Confirm that the phone number is valid and normalized to `+8801XXXXXXXXX`.
- Check Firebase Authentication logs and usage limits.

### Google sign-in fails

- Confirm that the Google provider is enabled.
- Confirm that Android SHA fingerprints are registered.
- Confirm that the web domain is authorized.
- Confirm that iOS URL schemes and client identifiers are configured.

### Notifications do not appear

- Grant notification permission.
- On Android, allow exact alarms when requested.
- Check that the operating system is not aggressively restricting background
  activity or battery usage.
- Confirm that the device time and time zone are correct.
- Remember that browser builds do not provide the same local-notification
  behavior as Android and iOS.

### Cloud backup does not complete

- Confirm that the user is still signed in.
- Deploy the repository's owner-only Firestore rules:

  ```powershell
  firebase deploy --only firestore:rules --project medimind-368ed
  ```

- Fully restart the app, then press **Backup** once to resume a cloud session
  that was paused after `permission-denied`.
- If the web build still reports a Firestore internal assertion after rules are
  deployed, first confirm that the local records have backed up successfully,
  then close its browser tab and clear that site's stored data before reopening
  it. Clearing site data resets stale Firestore web-client state but also erases
  that browser's Hive/IndexedDB records; it does not erase records stored in a
  native Android installation.
- Check Firestore and Storage security rules if photo upload alone fails.
- Check Firebase quotas and billing.
- Confirm that the network has actual internet access, not only a Wi-Fi or
  cellular connection indicator.
- Leave the dashboard open briefly after connectivity returns so the automatic
  retry can run.

### Dependency or build problems

Run:

```powershell
flutter clean
flutter pub get
flutter analyze
```

If the problem persists, compare `flutter doctor -v` with the platform
requirements and confirm that the selected Flutter SDK supports Dart 3.9.

## Security and privacy notes

- Phone numbers used for Firebase phone authentication are processed by Google
  and Firebase for verification and abuse prevention.
- The application does not contain a custom password authentication system.
- Do not log verification codes, authentication tokens, or private user data.
- Do not use open Firestore or Storage rules in production.
- Medicine photos can contain sensitive information and must remain protected by
  owner-only Storage rules.
- The reCAPTCHA badge is hidden only because the required reCAPTCHA disclosure
  remains visible in the phone-authentication flow.

## License

No application-level license has been declared in this repository. Add a
project license before public distribution. Third-party packages retain their
respective licenses, and bundled font licenses are included under
`assets/fonts`.
