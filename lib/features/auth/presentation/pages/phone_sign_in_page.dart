import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/auth_repository.dart';
import '../../domain/bangladesh_phone_number.dart';

class PhoneSignInPage extends StatefulWidget {
  const PhoneSignInPage({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  State<PhoneSignInPage> createState() => _PhoneSignInPageState();
}

class _PhoneSignInPageState extends State<PhoneSignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _busy = false;
  String? _verificationId;
  String? _normalizedPhoneNumber;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final normalizedPhoneNumber = BangladeshPhoneNumber.normalize(
      _phoneController.text,
    );

    setState(() => _busy = true);
    try {
      await widget.authRepository.sendPhoneVerificationCode(
        phoneNumber: normalizedPhoneNumber,
        onCodeSent: (verificationId) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _normalizedPhoneNumber = normalizedPhoneNumber;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Verification code sent.')),
            );
          }
        },
        onError: (errorMessage) {
          if (mounted) {
            _showError(StateError(errorMessage));
          }
        },
      );
    } catch (error) {
      if (mounted) {
        _showError(error);
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

    final smsCode = _codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(smsCode)) {
      _showError(const FormatException('Enter the 6-digit verification code.'));
      return;
    }

    setState(() => _busy = true);
    try {
      await widget.authRepository.signInWithSmsCode(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        _showError(error);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _showError(Object error) {
    if (!mounted) {
      return;
    }

    if (error case FirebaseAuthException(:final code, :final message)) {
      debugPrint('Firebase phone auth failed [$code]: $message');
    }

    final message = switch (error) {
      FirebaseAuthException(:final code) => switch (code) {
        'invalid-phone-number' => 'Enter a valid Bangladesh mobile number.',
        'billing-not-enabled' =>
          'Real verification SMS requires the Firebase Blaze billing plan.',
        'operation-not-allowed' =>
          'Phone sign-in is not enabled in Firebase Authentication.',
        'sms-region-not-allowed' || 'unsupported-country' =>
          'Firebase is not configured to send SMS to Bangladesh.',
        'unauthorized-domain' =>
          'This web address is not authorized in Firebase Authentication.',
        'invalid-app-credential' || 'captcha-check-failed' =>
          'Firebase could not verify this browser. Refresh and try again.',
        'too-many-requests' =>
          'Too many attempts. Please wait before requesting another code.',
        'quota-exceeded' =>
          'The Firebase SMS quota has been exceeded. Try again later.',
        'invalid-verification-code' => 'The verification code is incorrect.',
        'session-expired' || 'code-expired' =>
          'The verification code has expired. Request a new code.',
        _ => error.message ?? 'Authentication failed ($code).',
      },
      FormatException(:final message) => message,
      StateError(:final message) => message,
      _ => 'Authentication failed. Please try again.',
    };

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phone Sign In')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Form(
            key: _formKey,
            child: TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Bangladesh mobile number',
                hintText: '01712345678',
                helperText: 'You can enter +8801…, 01…, or 1…',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.telephoneNumber],
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9০-৯+\s\-()]')),
              ],
              validator: (value) {
                try {
                  BangladeshPhoneNumber.normalize(value ?? '');
                  return null;
                } on FormatException catch (error) {
                  return error.message.toString();
                }
              },
              onFieldSubmitted: (_) {
                if (!_busy) {
                  _requestCode();
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _requestCode,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Send code'),
            ),
          ),
          if (_normalizedPhoneNumber case final phoneNumber?) ...[
            const SizedBox(height: 12),
            Text(
              'Code sent to $phoneNumber',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            decoration: const InputDecoration(
              labelText: 'Verification code',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
