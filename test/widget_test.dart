import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medimind/app.dart';
import 'package:medimind/core/localization/app_localization.dart';
import 'package:medimind/features/auth/domain/app_user.dart';
import 'package:medimind/features/auth/domain/auth_repository.dart';
import 'package:medimind/features/auth/data/session_activity_store.dart';
import 'package:medimind/features/medication_reminder/domain/models/medication.dart';
import 'package:medimind/features/medication_reminder/domain/repositories/medication_repository.dart';

class FakeMedicationRepository implements MedicationRepository {
  FakeMedicationRepository({this.medications = const <Medication>[]});

  final List<Medication> medications;
  Medication? lastAdded;
  Medication? lastUpdated;

  @override
  Future<void> add({
    required String uid,
    required Medication medication,
  }) async {
    lastAdded = medication;
  }

  @override
  Future<void> delete({required String uid, required String id}) async {}

  @override
  Future<List<Medication>> getAll({required String uid}) async => medications;

  @override
  Future<Medication?> getById(String id) async => null;

  @override
  Future<void> backupToCloud({required String uid}) async {}

  @override
  Future<void> startAutoSync({required String uid}) async {}

  @override
  Future<void> stopAutoSync() async {}

  @override
  Future<void> update({
    required String uid,
    required Medication medication,
  }) async {
    lastUpdated = medication;
  }
}

class FakeSessionActivityStore implements SessionActivityStore {
  final Map<String, DateTime> _activities = <String, DateTime>{};

  @override
  Future<void> clear(String uid) async {
    _activities.remove(uid);
  }

  @override
  Future<DateTime?> readLastActivity(String uid) async => _activities[uid];

  @override
  Future<void> writeLastActivity(String uid, DateTime time) async {
    _activities[uid] = time;
  }
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository(this.user);

  final AppUser? user;

  @override
  Stream<AppUser?> get authStateChanges => Stream<AppUser?>.value(user);

  @override
  AppUser? get currentUser => user;

  @override
  Future<void> sendPhoneVerificationCode({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String errorMessage) onError,
  }) async {}

  @override
  Future<AppUser> signInWithGoogle() async => user!;

  @override
  Future<AppUser> signInWithSmsCode({
    required String verificationId,
    required String smsCode,
  }) async => user!;

  @override
  Future<void> signOut() async {}
}

void main() {
  test('mobile session expires after 30 days without activity', () {
    final now = DateTime(2026, 7, 22, 12);

    expect(
      isMobileSessionExpired(
        lastActivity: now.subtract(const Duration(days: 29)),
        now: now,
      ),
      isFalse,
    );
    expect(
      isMobileSessionExpired(
        lastActivity: now.subtract(const Duration(days: 30)),
        now: now,
      ),
      isTrue,
    );
  });

  testWidgets('shows only phone and Gmail sign-in options in Bangla', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MediMindApp(
        repository: FakeMedicationRepository(),
        authRepository: FakeAuthRepository(null),
        sessionActivityStore: FakeSessionActivityStore(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('মোবাইল নম্বর'), findsOneWidget);
    expect(find.text('জিমেইল অ্যাকাউন্ট'), findsOneWidget);
    expect(find.text('Email address'), findsNothing);
    expect(find.text('Password'), findsNothing);
    expect(find.text('Sign up'), findsNothing);

    await tester.tap(find.byIcon(Icons.phone_android));
    await tester.pumpAndSettle();
    final phoneInput = tester.widget<InputDecorator>(
      find.byType(InputDecorator).first,
    );
    expect(phoneInput.decoration.hintText, isNull);
    expect(phoneInput.decoration.helperText, isNull);
  });

  testWidgets('renders the Bangla dashboard for signed-in users', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MediMindApp(
        repository: FakeMedicationRepository(),
        authRepository: FakeAuthRepository(
          const AppUser(uid: 'test-user', displayName: 'Test User'),
        ),
        sessionActivityStore: FakeSessionActivityStore(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('আজকের ওষুধ'), findsOneWidget);
    expect(find.text('ঢাকা, বাংলাদেশ'), findsNothing);
    expect(find.text('ব্যাকআপ নিন'), findsNothing);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('ওষুধ যোগ করুন'), findsOneWidget);
  });

  testWidgets('language can be changed to English from the login screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MediMindApp(
        repository: FakeMedicationRepository(),
        authRepository: FakeAuthRepository(null),
        sessionActivityStore: FakeSessionActivityStore(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Eng'));
    await tester.pumpAndSettle();

    expect(find.text('Phone number'), findsOneWidget);
    expect(find.text('Gmail account'), findsOneWidget);
  });

  testWidgets('dashboard actions appear after a medicine exists', (
    WidgetTester tester,
  ) async {
    final medicine = Medication(
      id: 'one',
      medicineName: 'Napa',
      dose: '09:00 — 1 pill',
      durationDays: 0,
      timeOfDay: '09:00',
      mealOffset: 0,
      isActive: true,
      updatedAt: DateTime(2026, 7, 22),
    );
    await tester.pumpWidget(
      MediMindApp(
        repository: FakeMedicationRepository(medications: [medicine]),
        authRepository: FakeAuthRepository(
          const AppUser(uid: 'test-user', displayName: 'Test User'),
        ),
        sessionActivityStore: FakeSessionActivityStore(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ব্যাকআপ নিন'), findsOneWidget);
    expect(find.text('ওষুধ যোগ করুন'), findsOneWidget);
    expect(find.text('ঢাকা, বাংলাদেশ'), findsNothing);
  });

  testWidgets('medicine form is responsive and uses time plus dosage', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediMindApp(
        repository: FakeMedicationRepository(),
        authRepository: FakeAuthRepository(
          const AppUser(uid: 'test-user', displayName: 'Test User'),
        ),
        sessionActivityStore: FakeSessionActivityStore(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ওষুধ যোগ করুন').first);
    await tester.pumpAndSettle();

    expect(find.text('ওষুধের ধরন'), findsOneWidget);
    expect(find.text('শক্তির পরিমাণ'), findsOneWidget);
    expect(find.text('খাওয়ার সময় ও পরিমাণ'), findsOneWidget);
    expect(find.text('পরিমাণ'), findsOneWidget);

    await tester.tap(find.text('ট্যাবলেট'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ইনসুলিন').last);
    await tester.pumpAndSettle();
    expect(find.text('ইউনিট'), findsOneWidget);

    final timeButton = find.widgetWithIcon(OutlinedButton, Icons.access_time);
    final dosageInput = find.ancestor(
      of: find.text('পরিমাণ'),
      matching: find.byType(InputDecorator),
    );
    expect(
      (tester.getTopLeft(timeButton).dy - tester.getTopLeft(dosageInput).dy)
          .abs(),
      lessThan(1),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('খাবারের সময়ও মনে করিয়ে দিন'), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(find.text('খাবারের আগে'), findsOneWidget);
    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .any((field) => field.controller?.text == '20'),
      isTrue,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('ওষুধের ছবি'), findsOneWidget);
    expect(find.byIcon(Icons.logout_outlined), findsNothing);
    expect(find.byType(LanguageToggleButton), findsOneWidget);
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.decoration?.hintText, isNull);
      expect(field.decoration?.helperText, isNull);
    }
    expect(find.textContaining('Keep the form simple'), findsNothing);
    expect(find.text('Amount'), findsNothing);
  });

  testWidgets('medicine can be marked taken now from the dashboard', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeMedicationRepository(
      medications: [
        Medication(
          id: 'status-test',
          medicineName: 'Napa',
          dose: '1 pill',
          doses: const [
            MedicationDose(
              timeOfDay: '23:59',
              dosageValue: '1',
              dosageUnit: 'pill',
            ),
          ],
          durationDays: 0,
          timeOfDay: '23:59',
          mealOffset: -20,
          isActive: true,
          updatedAt: DateTime(2026, 7, 22),
        ),
      ],
    );

    await tester.pumpWidget(
      MediMindApp(
        repository: repository,
        authRepository: FakeAuthRepository(
          const AppUser(uid: 'test-user', displayName: 'Test User'),
        ),
        sessionActivityStore: FakeSessionActivityStore(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eng'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -850));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Taken').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Taken now'));
    await tester.pumpAndSettle();

    expect(repository.lastUpdated, isNotNull);
    expect(repository.lastUpdated!.checkIns.single.medicineStatus, 'taken');
    expect(repository.lastUpdated!.checkIns.single.medicineTakenAt, isNotNull);
  });
}
