# MediMind v1.0.0 - Reliable Medicine Reminders, Built Local-First

**Tag:** `v1.0.0`

MediMind v1.0.0 is the first complete release of the bilingual medicine
reminder and adherence experience. It combines dependable local scheduling,
fast offline-first data handling, actionable Android notifications, private
Firebase backup, and clear 7-day and 30-day reporting.

## Highlights

- Medicine-only reminders focused on the core adherence workflow.
- Bengali and English interfaces with consistent visual emphasis.
- English 12-hour `AM/PM` time formatting in both language modes.
- High-priority Android reminders with sound, vibration, lock-screen
  visibility, and Taken/Not taken actions.
- Screen wake at reminder time without forcing MediMind over another app.
- Grouped reminders when multiple medicines share the same scheduled minute.
- Centered in-app reminder dialog with a blurred backdrop and direct actions.
- Fast local saves with report, scheduling, and backup maintenance moved to
  coalesced background work.
- Change-driven automatic Firebase backup with visible progress.

## Medicine Scheduling

- Create and edit tablet, capsule, syrup, drop, and insulin reminders.
- Store strength, formula, company, notes, and an optional medicine photo.
- Add multiple daily dose times with individual dosage values.
- Use daily, weekly, every-15-days, monthly, or 1-365 day custom recurrence.
- Preserve monthly schedules safely across shorter months.
- Keep predefined recurrence clean in Firestore by storing custom interval
  values only for custom schedules.
- Detect likely duplicate reminders using medicine identity and dosage data.
- Confirm reminder deletion through a localized Yes/No dialog.

## Reminder Experience

- Exact Android scheduling where the operating system grants access.
- Inexact while-idle fallback when exact alarms are unavailable.
- Sound, vibration, maximum-priority heads-up banners, and public lock-screen
  content.
- A companion Android wake alarm turns on the display briefly while leaving
  the lock screen and notification in control.
- Notification actions record Taken or Not taken without opening the app.
- Opening a reminder notification shows the full in-app reminder dialog.
- Same-time medicines are listed together across the lock screen,
  notification panel, and in-app dialog.
- Scheduled reminders are restored after supported device reboot events.
- iOS reminders use the Time Sensitive interruption level.

## Dashboard and Tracking

- Live arc from the actual current time to the next meaningful medicine event.
- Current time and all schedule times displayed in English 12-hour format.
- Live due-in countdown inside the arc.
- Centered Today and Active metrics.
- Superscript English ordinal date suffixes.
- Side-by-side Add medicine and Backup controls.
- Taken/Not taken controls become available five minutes before a dose.
- Status controls disappear after the occurrence is recorded.
- Optional medicine artwork appears on dashboard cards and supported Android
  notifications.

## Reports

- Local-first 7-day and 30-day adherence reports.
- Taken and not-taken summaries.
- Scheduled and actual medicine times.
- Detailed daily history.
- Historical entries retained after a medicine is deleted.
- Owner-scoped Firestore report snapshots during backup.

## Backup and Performance

- Hive remains the local source of truth.
- Medicine saves and adherence updates return after the local write.
- Report generation and notification rescheduling run in serialized,
  coalesced background work.
- Automatic backup occurs only after meaningful state changes.
- Existing Firestore reminders are restored into local storage at sign-in.
- The newest local or cloud reminder version wins during startup hydration.
- Local medicine storage is isolated by account on shared devices.
- Connectivity recovery retries pending backups.
- Offline deletions are retained and mirrored to the cloud later.
- The Backup button displays a spinner and `Backing up...` during automatic
  and manual backup operations.
- Inline progress indicators cover OTP sending, verification, medicine saving,
  Google sign-in, sign-out, and backup.

## Localization and Design

- Bengali-first interface with per-device language persistence across
  sign-in, sign-out, force-stop, and restart.
- English interface available from the segmented language control.
- Matching bold text roles across Bengali and English.
- Bundled Manrope and Noto Sans Bengali fonts.
- New MediMind identity across launcher, adaptive icon, round icon, splash
  screen, sign-in, and reminder dialog, with the wordmark on the dashboard.
- Responsive behavior tested on narrow phone layouts.

## Authentication and Privacy

- Bangladesh phone-number authentication with flexible input normalization.
- Google/Gmail sign-in.
- Persistent mobile sessions with a 30-day inactivity limit.
- Owner-scoped Firestore reminders and reports.
- Optional medicine photo backup through Firebase Storage.
- Local functionality remains available when cloud services are offline.

## Quality

- `flutter analyze` passes with no issues.
- All 66 unit and widget tests pass.
- Debug and release Android APK builds complete successfully.

## Installation Notes

Android users should allow:

- Notifications.
- Exact alarms, where prompted.
- Sound and vibration for the MediMind reminder channel.
- Lock-screen and heads-up notification visibility.

Some manufacturers apply additional battery restrictions. If reminders are
delayed, allow MediMind to run in the background and exclude it from aggressive
battery optimization.

## Upgrade Notes

- Existing local medicine records remain readable.
- The next successful backup removes irrelevant `customIntervalDays` fields
  from predefined recurrence documents.
- Android may preserve old launcher artwork or notification-channel settings
  after an in-place install. Reinstalling the app refreshes launcher assets;
  notification-channel behavior can be reviewed in Android system settings.

---

Thank you for using MediMind.
