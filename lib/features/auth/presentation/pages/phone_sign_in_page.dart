import 'package:flutter/material.dart';

import '../../domain/auth_repository.dart';

class PhoneSignInPage extends StatefulWidget {
  const PhoneSignInPage({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  State<PhoneSignInPage> createState() => _PhoneSignInPageState();
}

class _PhoneSignInPageState extends State<PhoneSignInPage> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _busy = false;
  String? _verificationId;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    setState(() => _busy = true);
    try {
      await widget.authRepository.sendPhoneVerificationCode(
        phoneNumber: _phoneController.text.trim(),
        onCodeSent: (verificationId) {
          setState(() => _verificationId = verificationId);
        },
        onError: (errorMessage) {
          throw StateError(errorMessage);
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification code sent.')),
        );
      }
    } catch (error) {
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

  Future<void> _verify() async {
    final verificationId = _verificationId;
    if (verificationId == null || verificationId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request the verification code first.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await widget.authRepository.signInWithSmsCode(
        verificationId: verificationId,
        smsCode: _codeController.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
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
      appBar: AppBar(title: const Text('Phone Sign In')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone number',
              helperText: 'Use +8801XXXXXXXXX format',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _requestCode,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Send code'),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            decoration: const InputDecoration(
              labelText: 'Verification code',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy ? null : _verify,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Verify and sign in'),
            ),
          ),
        ],
      ),
    );
  }
}
