import 'package:flutter/material.dart';

import '../../../../core/localization/app_localization.dart';
import '../../domain/auth_repository.dart';
import 'google_sign_in_page.dart';
import 'phone_sign_in_page.dart';
import 'sign_up_page.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;
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
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(color: Colors.grey.shade200),
  }
      }
    }
  }

  Future<void> _signInEmail() async {
    await _runAction(() async {
                          context.tr('sign_in'),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    });
  }

  void _openSignUp() {
                          decoration: InputDecoration(
                            labelText: context.tr('email_address'),
        builder: (_) => SignUpPage(authRepository: widget.authRepository),
      ),
    );
  }

  void _openPhoneSignIn() {
    Navigator.of(context).push(
                          decoration: InputDecoration(
                            labelText: context.tr('password'),
      ),
    );
  }

  void _openGoogleSignIn() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GoogleSignInPage(authRepository: widget.authRepository),
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
                Text(
                  'MediMind',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF153E75),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'সহজ, পরিষ্কার, ওষুধ মনে রাখার জন্য তৈরি।',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Sign in',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email address',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 16),
                        Semantics(
                          button: true,
                          label: context.tr('sign_in_with_email'),
                          child: FilledButton(
                            onPressed: _busy ? null : _signInEmail,
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Text(context.tr('sign_in')),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _busy ? null : _openSignUp,
                          child: Text(context.tr('sign_up')),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr('other_sign_in_options'),
                  style: theme.textTheme.titleMedium?.copyWith(
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
                  onTap: _openGoogleSignIn,
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

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
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
