import 'package:flutter/material.dart';

import '../../../../core/localization/app_localization.dart';
import '../../domain/auth_repository.dart';
import 'phone_sign_in_page.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  bool _googleBusy = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _googleBusy = true);
    try {
      await widget.authRepository.signInWithGoogle();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _googleBusy = false);
      }
    }
  }

  void _openPhoneSignIn() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhoneSignInPage(authRepository: widget.authRepository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: ListView(
              padding: const EdgeInsets.all(16),
              shrinkWrap: true,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr('app_name'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF153E75),
                        ),
                      ),
                    ),
                    const LanguageToggleButton(),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('tagline'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                Text(
                  context.tr('choose_sign_in'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                _MethodTile(
                  icon: Icons.phone_android,
                  title: context.tr('phone_number'),
                  subtitle: context.tr('phone_sign_in_subtitle'),
                  onTap: _openPhoneSignIn,
                ),
                const SizedBox(height: 10),
                _MethodTile(
                  icon: Icons.account_circle_outlined,
                  title: context.tr('google_account'),
                  subtitle: context.tr('google_sign_in_subtitle'),
                  onTap: _googleBusy ? null : _signInWithGoogle,
                  loading: _googleBusy,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE8F0FE),
          child: Icon(icon, color: const Color(0xFF153E75)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: loading
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}
