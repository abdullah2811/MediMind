import 'package:flutter/material.dart';

import '../../../../core/localization/app_localization.dart';
import '../../domain/auth_repository.dart';

class GoogleSignInPage extends StatefulWidget {
  const GoogleSignInPage({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  State<GoogleSignInPage> createState() => _GoogleSignInPageState();
}

class _GoogleSignInPageState extends State<GoogleSignInPage> {
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      await widget.authRepository.signInWithGoogle();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('google_sign_in'))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_circle, size: 80),
              const SizedBox(height: 16),
              Text(
                context.tr('continue_google'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('continue_google_subtitle'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _busy ? null : _signIn,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.account_circle_outlined),
                label: Text(context.tr('continue_google')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
