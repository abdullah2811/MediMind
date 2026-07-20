import 'package:flutter_test/flutter_test.dart';

import 'package:medimind/app.dart';
import 'package:medimind/features/auth/domain/app_user.dart';
import 'package:medimind/features/auth/domain/auth_repository.dart';
import 'package:medimind/features/medication_reminder/domain/models/medication.dart';
import 'package:medimind/features/medication_reminder/domain/repositories/medication_repository.dart';

class FakeMedicationRepository implements MedicationRepository {
  @override
  Future<void> add({
    required String uid,
    required Medication medication,
  }) async {}

  @override
  Future<void> delete({required String uid, required String id}) async {}

  @override
  Future<List<Medication>> getAll({required String uid}) async =>
      <Medication>[];

  @override
  Future<Medication?> getById(String id) async => null;

  @override
  Future<void> syncFromCloud({required String uid}) async {}

  @override
  Future<void> backupToCloud({required String uid}) async {}

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
  Future<AppUser> signInWithGoogle() async {
    return user!;
  }

  @override
  Future<AppUser> signInWithSmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    return user!;
  }

  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets('shows only phone and Gmail sign-in options', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MediMindApp(
        repository: FakeMedicationRepository(),
        authRepository: FakeAuthRepository(null),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Phone number'), findsOneWidget);
    expect(find.text('Gmail account'), findsOneWidget);
    expect(find.text('Email address'), findsNothing);
    expect(find.text('Password'), findsNothing);
    expect(find.text('Sign up'), findsNothing);
  });

  testWidgets('renders the dashboard for signed-in users', (
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
    expect(find.text('Dhaka, Bangladesh'), findsOneWidget);
  });
}
