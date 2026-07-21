import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medimind/app.dart';
import 'package:medimind/features/auth/domain/app_user.dart';
import 'package:medimind/features/auth/domain/auth_repository.dart';
import 'package:medimind/features/medication_reminder/domain/models/medication.dart';
import 'package:medimind/features/medication_reminder/domain/repositories/medication_repository.dart';

class FakeMedicationRepository implements MedicationRepository {
  FakeMedicationRepository({this.medications = const <Medication>[]});

  final List<Medication> medications;
  Medication? lastAdded;

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
  Future<void> syncFromCloud({required String uid}) async {}

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
  }) async {}
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
  testWidgets('shows only phone and Gmail sign-in options in Bangla', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MediMindApp(
        repository: FakeMedicationRepository(),
        authRepository: FakeAuthRepository(null),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('মোবাইল নম্বর'), findsOneWidget);
    expect(find.text('জিমেইল অ্যাকাউন্ট'), findsOneWidget);
    expect(find.text('Email address'), findsNothing);
    expect(find.text('Password'), findsNothing);
    expect(find.text('Sign up'), findsNothing);
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
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('খাবারের সময়ও মনে করিয়ে দিন'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('ওষুধের ছবি'), findsOneWidget);
    expect(find.textContaining('Keep the form simple'), findsNothing);
    expect(find.text('Amount'), findsNothing);
  });
}
