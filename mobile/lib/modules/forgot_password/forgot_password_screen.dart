import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_strings.dart';
import '../../routes.dart';
import '../../services/auth_service.dart';
import '../../shared/components/components.dart';
import '../../shared/network/local/cache_helper.dart' show ApiFailure;
import '../../shared/styles/colors.dart';
import '../../shared/utils/validators.dart';

/// Step 1 of password recovery: enter the email or phone number of the
/// account → the backend sends a 6-digit reset code. The next screen
/// verifies the code and sets the new password.
///
/// This flow exists because a forgotten password previously locked an
/// elderly patient out of the app — and out of their medication reminders —
/// with no self-service way back in.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _auth = AuthService();

  bool _byPhone = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final identifier =
        (_byPhone ? _phoneController.text : _emailController.text).trim();
    try {
      await _auth.requestPasswordReset(identifier);
      if (!mounted) return;
      // Move on to step 2 — the code entry screen.
      context.push(Routes.resetPassword, extra: identifier);
    } catch (e) {
      setState(() => _error = e is ApiFailure ? e.message : 'err.network');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('forgot.title')),
        actions: const [LanguageToggle()],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: GlassCard(
              padding: const EdgeInsets.all(24),
              radius: 28,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(18),
                      child: const Icon(Icons.lock_reset_outlined,
                          size: 44, color: AppColors.primary),
                    ),
                    const SizedBox(height: 16),
                    Text(context.tr('forgot.title'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(context.tr('forgot.subtitle'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 24),

                    // ---- Identifier method: email / phone (mirrors login) ----
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: 'email',
                          icon: const Icon(Icons.email_outlined, size: 18),
                          label: Text(context.tr('login.method.email')),
                        ),
                        ButtonSegment(
                          value: 'phone',
                          icon: const Icon(Icons.phone_outlined, size: 18),
                          label: Text(context.tr('login.method.phone')),
                        ),
                      ],
                      selected: {_byPhone ? 'phone' : 'email'},
                      onSelectionChanged: (s) =>
                          setState(() => _byPhone = s.first == 'phone'),
                    ),
                    const SizedBox(height: 20),
                    if (_byPhone)
                      DefaultFormField(
                        controller: _phoneController,
                        label: context.tr('login.phone'),
                        hint: '01xxxxxxxxx',
                        prefixIcon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: (v) =>
                            AppValidators.isValidEgyptianPhone(v ?? '')
                                ? null
                                : context.tr('login.invalidPhone'),
                      )
                    else
                      DefaultFormField(
                        controller: _emailController,
                        label: context.tr('login.email'),
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => (v == null || !v.contains('@'))
                            ? context.tr('login.invalidEmail')
                            : null,
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(context.trv(_error!),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.danger)),
                    ],
                    const SizedBox(height: 16),
                    DefaultButton(
                      label: context.tr('forgot.sendCode'),
                      loading: _loading,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.go(Routes.login),
                      child: Text(context.tr('forgot.backToLogin')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
