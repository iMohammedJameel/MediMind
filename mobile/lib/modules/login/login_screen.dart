import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_strings.dart';
import '../../services/biometric_service.dart';
import '../../shared/components/components.dart';
import '../../shared/styles/colors.dart';
import '../../shared/components/constants.dart';
import '../../shared/utils/validators.dart';
import '../../app_router.dart';
import 'cubit/login_cubit.dart';
import 'cubit/login_states.dart';

/// Login with email OR mobile number (both supported by the backend —
/// phone login is the norm for the elderly Egyptian market).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    // Controllers are ChangeNotifiers — they must be disposed with the
    // State, otherwise every login/logout cycle leaks them.
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Post-login one-time offer to enable fingerprint/face unlock.
  /// Silently skipped when the device can't do biometrics or the user
  /// already opted in (Settings can always change it later).
  Future<void> _offerBiometricUnlock(BuildContext context) async {
    final bio = BiometricService.instance;
    if (!await bio.isSupported() || await bio.isEnabled()) return;
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!context.mounted) return;
    final locale = context.lang;
    final wantsIt = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(S.get('biometric.offerTitle', locale)),
        content: Text(S.get('biometric.offerBody', locale)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(S.get('common.cancel', locale)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(S.get('biometric.enable', locale)),
          ),
        ],
      ),
    );
    if (wantsIt == true) {
      await bio.setEnabled(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LoginCubit(),
      child: BlocConsumer<LoginCubit, LoginStates>(
        listener: (context, state) {
          if (state is LoginSuccess) {
            // Same role logic as the router's _homeFor — the old hardcoded
            // check sent DOCTOR accounts to the patient home (the router
            // then bounced them, causing a visible redirect flash).
            if (state.role == AppConstants.rolePharmacist) {
              context.go(Routes.unsupportedRole);
              return;
            }
            final isCaregiver =
                AppConstants.caregiverRoles.contains(state.role) ||
                    state.role == AppConstants.roleDoctor;
            context.go(isCaregiver ? Routes.caregiverHome : Routes.patientHome);
            // One-time offer: right after a successful password entry is
            // the natural moment to offer biometric unlock for next time
            // (elderly users benefit the most — one touch instead of
            // typing a password every launch).
            unawaited(_offerBiometricUnlock(context));
          }
        },
        builder: (context, state) {
          final cubit = context.read<LoginCubit>();
          final byPhone = cubit.byPhone;
          return Scaffold(
            appBar: AppBar(
              // Language switch BEFORE login — English users used to be
              // stuck on Arabic-only auth screens.
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
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: Image.asset(
                                'assets/medimind_appicon.png',
                                width: 84,
                                height: 84,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('MediMind',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineLarge),
                        Text(context.tr('login.tagline'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge),
                        const SizedBox(height: 24),

                        // ---- Login method: email / phone ----
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
                          selected: {byPhone ? 'phone' : 'email'},
                          onSelectionChanged: (s) =>
                              cubit.setMethod(byPhone: s.first == 'phone'),
                        ),
                        const SizedBox(height: 20),

                        if (byPhone)
                          DefaultFormField(
                            controller: _phoneController,
                            label: context.tr('login.phone'),
                            hint: '01xxxxxxxxx',
                            prefixIcon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
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
                            textInputAction: TextInputAction.next,
                            validator: (v) =>
                                AppValidators.isValidEmail(v ?? '')
                                    ? null
                                    : context.tr('login.invalidEmail'),
                          ),
                        const SizedBox(height: 16),
                        DefaultFormField(
                          controller: _passwordController,
                          label: context.tr('login.password'),
                          prefixIcon: Icons.lock_outline,
                          obscureText: cubit.obscurePassword,
                          textInputAction: TextInputAction.done,
                          suffixIcon: IconButton(
                            tooltip: cubit.obscurePassword
                                ? context.tr('login.showPassword')
                                : context.tr('login.hidePassword'),
                            icon: Icon(
                              cubit.obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            onPressed: cubit.togglePasswordVisibility,
                          ),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? context.tr('login.passwordRequired') : null,
                        ),
                        if (state is LoginError) ...[
                          const SizedBox(height: 8),
                          Text(context.trv(state.message),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.danger)),
                        ],
                        const SizedBox(height: 12),
                        // Self-service recovery — previously a forgotten
                        // password permanently locked the patient out of
                        // their reminders.
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton(
                            onPressed: () => context.push(Routes.forgotPassword),
                            child: Text(context.tr('login.forgotPassword')),
                          ),
                        ),
                        const SizedBox(height: 4),
                        DefaultButton(
                          label: context.tr('login.submit'),
                          loading: state is LoginLoading,
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              cubit.login(
                                email: _emailController.text.trim(),
                                phone: _phoneController.text.trim(),
                                password: _passwordController.text,
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => context.go(Routes.register),
                          child: Text(context.tr('login.register')),
                        ),
                      ],
                    ),
                  ),
                ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
