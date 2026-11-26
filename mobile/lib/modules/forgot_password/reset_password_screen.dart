import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_strings.dart';
import '../../routes.dart';
import '../../services/auth_service.dart';
import '../../shared/components/components.dart';
import '../../shared/network/local/cache_helper.dart' show ApiFailure;
import '../../shared/styles/colors.dart';

/// Step 2 of password recovery: enter the 6-digit code that was sent to the
/// account + the new password (typed twice — elderly-friendly safety).
class ResetPasswordScreen extends StatefulWidget {
  /// The identifier (email or phone) the code was sent for — travels as the
  /// route extra from the forgot-password screen.
  final String? identifier;

  const ResetPasswordScreen({super.key, this.identifier});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _auth = AuthService();

  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _identifierController.text = widget.identifier ?? '';
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.resetPassword(
        identifier: _identifierController.text.trim(),
        code: _codeController.text.trim(),
        newPassword: _passwordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.tr('forgot.resetSuccess')),
          backgroundColor: AppColors.success));
      context.go(Routes.login);
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
        title: Text(context.tr('forgot.resetTitle')),
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
                      child: const Icon(Icons.password_outlined,
                          size: 44, color: AppColors.primary),
                    ),
                    const SizedBox(height: 16),
                    Text(context.tr('forgot.resetSubtitle'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 24),

                    DefaultFormField(
                      controller: _identifierController,
                      label: context.tr('forgot.identifier'),
                      prefixIcon: Icons.alternate_email,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? context.tr('common.required')
                          : null,
                    ),
                    const SizedBox(height: 16),
                    DefaultFormField(
                      controller: _codeController,
                      label: context.tr('forgot.code'),
                      hint: '123456',
                      prefixIcon: Icons.pin_outlined,
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          (v == null || v.trim().length != 6 || int.tryParse(v.trim()) == null)
                              ? context.tr('forgot.invalidCode')
                              : null,
                    ),
                    const SizedBox(height: 16),
                    DefaultFormField(
                      controller: _passwordController,
                      label: context.tr('forgot.newPassword'),
                      prefixIcon: Icons.lock_outline,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.next,
                      suffixIcon: IconButton(
                        tooltip: _obscure
                            ? context.tr('login.showPassword')
                            : context.tr('login.hidePassword'),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      validator: (v) =>
                          (v == null || v.length < 8) ? context.tr('register.passwordHint') : null,
                    ),
                    const SizedBox(height: 16),
                    DefaultFormField(
                      controller: _confirmController,
                      label: context.tr('register.confirmPassword'),
                      prefixIcon: Icons.lock_outline,
                      obscureText: _obscure,
                      validator: (v) => (v != _passwordController.text)
                          ? context.tr('err.passwordMismatch')
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
                      label: context.tr('forgot.resetSubmit'),
                      loading: _loading,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => context.push(Routes.forgotPassword),
                      child: Text(context.tr('forgot.resendCode')),
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
