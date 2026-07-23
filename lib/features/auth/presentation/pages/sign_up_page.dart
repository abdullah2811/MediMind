import 'package:flutter/material.dart';

import '../../../../core/localization/app_localization.dart';
import '../../domain/auth_repository.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      return;
    }

    setState(() => _busy = true);
    try {
      await widget.authRepository.signUpWithEmailAndPassword(
        email: email,
        password: password,
        displayName: name,
      );
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
      appBar: AppBar(title: Text(context.tr('create_account'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: context.tr('full_name'),
              border: const OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: context.tr('email_address'),
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: context.tr('password'),
              border: const OutlineInputBorder(),
            ),
            obscureText: true,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _signUp,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(context.tr('create_account')),
            ),
          ),
        ],
      ),
    );
  }
}
