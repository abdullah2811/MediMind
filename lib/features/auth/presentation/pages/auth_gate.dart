import 'package:flutter/material.dart';

import '../../../medication_reminder/domain/repositories/medication_repository.dart';
import '../../../medication_reminder/presentation/pages/medication_dashboard_page.dart';
import '../../domain/auth_repository.dart';
import '../../domain/app_user.dart';
import 'sign_in_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.authRepository,
    required this.medicationRepository,
  });

  final AuthRepository authRepository;
  final MedicationRepository medicationRepository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: authRepository.authStateChanges,
      initialData: authRepository.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) {
          return SignInPage(authRepository: authRepository);
        }

        return MedicationDashboardPage(
          uid: user.uid,
          repository: medicationRepository,
          onSignOut: authRepository.signOut,
        );
      },
    );
  }
}
