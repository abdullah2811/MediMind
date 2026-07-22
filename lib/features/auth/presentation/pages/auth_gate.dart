import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../medication_reminder/domain/repositories/medication_repository.dart';
import '../../../medication_reminder/presentation/pages/medication_dashboard_page.dart';
import '../../data/session_activity_store.dart';
import '../../domain/auth_repository.dart';
import '../../domain/app_user.dart';
import 'sign_in_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.authRepository,
    required this.medicationRepository,
    required this.sessionActivityStore,
  });

  final AuthRepository authRepository;
  final MedicationRepository medicationRepository;
  final SessionActivityStore sessionActivityStore;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  String? _validatedUid;
  Future<bool>? _validation;

  bool get _usesMobileSessionPolicy {
    return !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final user = widget.authRepository.currentUser;
    if (!_usesMobileSessionPolicy || user == null) {
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _validatedUid = user.uid;
      _validation = _validateAndTouch(user.uid);
      if (mounted) {
        setState(() {});
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(
        widget.sessionActivityStore.writeLastActivity(user.uid, DateTime.now()),
      );
    }
  }

  Future<bool> _validateAndTouch(String uid) async {
    final now = DateTime.now();
    final lastActivity = await widget.sessionActivityStore.readLastActivity(
      uid,
    );
    if (isMobileSessionExpired(lastActivity: lastActivity, now: now)) {
      await widget.sessionActivityStore.clear(uid);
      await widget.authRepository.signOut();
      return false;
    }
    await widget.sessionActivityStore.writeLastActivity(uid, now);
    return true;
  }

  Future<void> _signOut(String uid) async {
    await widget.sessionActivityStore.clear(uid);
    await widget.authRepository.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: widget.authRepository.authStateChanges,
      initialData: widget.authRepository.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) {
          _validatedUid = null;
          _validation = null;
          return SignInPage(authRepository: widget.authRepository);
        }

        Widget dashboard() => MedicationDashboardPage(
          uid: user.uid,
          repository: widget.medicationRepository,
          onSignOut: () => _signOut(user.uid),
        );

        if (!_usesMobileSessionPolicy) {
          return dashboard();
        }

        if (_validatedUid != user.uid || _validation == null) {
          _validatedUid = user.uid;
          _validation = _validateAndTouch(user.uid);
        }

        return FutureBuilder<bool>(
          future: _validation,
          builder: (context, validationSnapshot) {
            if (validationSnapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (validationSnapshot.data != true) {
              return SignInPage(authRepository: widget.authRepository);
            }
            return dashboard();
          },
        );
      },
    );
  }
}
