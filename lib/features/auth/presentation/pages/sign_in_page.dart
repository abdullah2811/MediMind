import 'package:flutter/material.dart';

import '../../../../core/localization/app_localization.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/medimind_logo.dart';
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

  void _openPhoneSignIn() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhoneSignInPage(authRepository: widget.authRepository),
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    if (_googleBusy) {
      return;
    }
    setState(() => _googleBusy = true);
    try {
      await widget.authRepository.signInWithGoogle();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr('auth_failed')} ${error.toString()}'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _googleBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppPalette.ivory,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 40,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Align(
                          alignment: Alignment.centerRight,
                          child: LanguageToggleButton(),
                        ),
                        const SizedBox(height: 36),
                        Align(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: AppPalette.aubergine.withValues(
                                    alpha: 0.2,
                                  ),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const MediMindLogo(
                              size: 92,
                              borderRadius: 22,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          'MediMind',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppPalette.aubergine,
                            fontSize: 34,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.tr('tagline'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppPalette.muted,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          context.tr('choose_sign_in'),
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: AppPalette.aubergine,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _SignInMethodCard(
                          icon: Icons.phone_android,
                          title: context.tr('phone_number'),
                          subtitle: context.tr('phone_sign_in_subtitle'),
                          onTap: _openPhoneSignIn,
                        ),
                        const SizedBox(height: 12),
                        _SignInMethodCard(
                          icon: Icons.account_circle_outlined,
                          title: context.tr('google_account'),
                          subtitle: context.tr('google_sign_in_subtitle'),
                          busy: _googleBusy,
                          onTap: _signInWithGoogle,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SignInMethodCard extends StatelessWidget {
  const _SignInMethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: AppPalette.plum.withValues(alpha: 0.14)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppPalette.blush.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(icon, color: AppPalette.persimmon),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppPalette.aubergine,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppPalette.muted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (busy)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              else
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppPalette.aubergine,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
