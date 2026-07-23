import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/link.dart';

import '../../../../core/localization/app_localization.dart';
import '../../../../core/widgets/inline_button_progress.dart';
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
  _PhoneOperation? _operation;
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

    setState(() => _operation = _PhoneOperation.sendingCode);
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
              SnackBar(content: Text(context.tr('verification_sent'))),
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
        setState(() => _operation = null);
      }
    }
  }

  Future<void> _verify() async {
    final verificationId = _verificationId;
    if (verificationId == null || verificationId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('request_code_first'))));
      return;
    }

    final smsCode = _codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(smsCode)) {
      _showError(FormatException(context.tr('enter_six_digit_code')));
      return;
    }

    setState(() => _operation = _PhoneOperation.verifying);
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
        setState(() => _operation = null);
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
        'invalid-phone-number' => context.tr('invalid_phone'),
        'billing-not-enabled' => context.tr('billing_required'),
        'operation-not-allowed' => context.tr('phone_disabled'),
        'sms-region-not-allowed' ||
        'unsupported-country' => context.tr('region_blocked'),
        'unauthorized-domain' => context.tr('unauthorized_domain'),
        'invalid-app-credential' ||
        'captcha-check-failed' => context.tr('browser_verification_failed'),
        'too-many-requests' => context.tr('too_many_requests'),
        'quota-exceeded' => context.tr('quota_exceeded'),
        'invalid-verification-code' => context.tr('invalid_code'),
        'session-expired' || 'code-expired' => context.tr('expired_code'),
        _ => error.message ?? 'Authentication failed ($code).',
      },
      FormatException(:final message) => message,
      StateError(:final message) => message,
      _ => context.tr('auth_failed'),
    };

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('phone_sign_in'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Form(
            key: _formKey,
            child: TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: context.tr('bangladesh_mobile_number'),
                border: const OutlineInputBorder(),
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
                } on FormatException {
                  return context.tr('invalid_phone');
                }
              },
              onFieldSubmitted: (_) {
                if (_operation == null) {
                  _requestCode();
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _operation == null ? _requestCode : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: InlineButtonProgress(
                label: context.tr('send_code'),
                inProgress: _operation == _PhoneOperation.sendingCode,
              ),
            ),
          ),
          if (_normalizedPhoneNumber case final phoneNumber?) ...[
            const SizedBox(height: 12),
            Text(
              '${context.tr('code_sent_to')} $phoneNumber',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            decoration: InputDecoration(
              labelText: context.tr('verification_code'),
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _operation == null ? _verify : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: InlineButtonProgress(
                label: context.tr('verify_and_sign_in'),
                inProgress: _operation == _PhoneOperation.verifying,
              ),
            ),
          ),
          if (kIsWeb) ...[
            const SizedBox(height: 24),
            const _RecaptchaDisclosure(),
          ],
        ],
      ),
    );
  }
}

enum _PhoneOperation { sendingCode, verifying }

class _RecaptchaDisclosure extends StatelessWidget {
  const _RecaptchaDisclosure();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11);
    final linkStyle = style?.copyWith(
      decoration: TextDecoration.underline,
      fontWeight: FontWeight.w700,
    );
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 3,
      children: [
        Text(
          'This site is protected by reCAPTCHA and the Google',
          style: style,
        ),
        Link(
          uri: Uri.parse('https://policies.google.com/privacy'),
          target: LinkTarget.blank,
          builder: (context, followLink) => InkWell(
            onTap: followLink,
            child: Text('Privacy Policy', style: linkStyle),
          ),
        ),
        Text('and', style: style),
        Link(
          uri: Uri.parse('https://policies.google.com/terms'),
          target: LinkTarget.blank,
          builder: (context, followLink) => InkWell(
            onTap: followLink,
            child: Text('Terms of Service', style: linkStyle),
          ),
        ),
        Text('apply.', style: style),
      ],
    );
  }
}
