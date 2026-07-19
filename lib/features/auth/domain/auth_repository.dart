import 'app_user.dart';

abstract class AuthRepository {
  Stream<AppUser?> get authStateChanges;

  AppUser? get currentUser;

  Future<AppUser> createAccountWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  });

  Future<AppUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<AppUser> signInWithGoogle();

  Future<void> sendPhoneVerificationCode({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String errorMessage) onError,
  });

  Future<AppUser> signInWithSmsCode({
    required String verificationId,
    required String smsCode,
  });

  Future<void> signOut();
}
