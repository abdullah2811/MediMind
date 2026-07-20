import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../domain/app_user.dart';
import '../domain/auth_repository.dart';
import '../domain/bangladesh_phone_number.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({required FirebaseAuth auth}) : _auth = auth;

  final FirebaseAuth _auth;
  GoogleSignIn? _googleSignIn;

  GoogleSignIn get _nativeGoogleSignIn =>
      _googleSignIn ??= GoogleSignIn(scopes: <String>['email']);

  @override
  Stream<AppUser?> get authStateChanges => _auth.authStateChanges().map(
    (user) => user == null ? null : _mapUser(user),
  );

  @override
  AppUser? get currentUser {
    final user = _auth.currentUser;
    return user == null ? null : _mapUser(user);
  }

  @override
  Future<void> sendPhoneVerificationCode({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String errorMessage) onError,
  }) async {
    final normalizedPhoneNumber = BangladeshPhoneNumber.normalize(phoneNumber);

    if (kIsWeb) {
      // Firebase manages the required web reCAPTCHA verifier. With no custom
      // verifier supplied, it uses the default invisible flow.
      final result = await _auth.signInWithPhoneNumber(normalizedPhoneNumber);
      onCodeSent(result.verificationId);
      return;
    }

    await _auth.verifyPhoneNumber(
      phoneNumber: normalizedPhoneNumber,
      verificationCompleted: (credential) async {
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: (exception) {
        onError(exception.message ?? exception.code);
      },
      codeSent: (verificationId, _) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    if (kIsWeb) {
      final credential = await _auth.signInWithPopup(GoogleAuthProvider());
      return _mapCredentialUser(credential);
    }

    final googleUser = await _nativeGoogleSignIn.signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'canceled',
        message: 'Google sign-in was cancelled.',
      );
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    return _mapCredentialUser(userCredential);
  }

  @override
  Future<AppUser> signInWithSmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    return _mapCredentialUser(userCredential);
  }

  @override
  Future<void> signOut() async {
    if (!kIsWeb) {
      await _googleSignIn?.signOut();
    }
    await _auth.signOut();
  }

  AppUser _mapCredentialUser(UserCredential credential) {
    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-null',
        message: 'Authentication succeeded but no user was returned.',
      );
    }
    return _mapUser(user);
  }

  AppUser _mapUser(User user) {
    return AppUser(
      uid: user.uid,
      displayName: user.displayName,
      email: user.email,
      phoneNumber: user.phoneNumber,
    );
  }
}
