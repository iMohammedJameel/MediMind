import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../app_router.dart';
import '../../l10n/app_strings.dart';
import '../../shared/components/components.dart';
import '../../shared/utils/validators.dart';
import 'cubit/register_cubit.dart';
import 'cubit/register_states.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => RegisterCubit(),
      child: BlocConsumer<RegisterCubit, RegisterStates>(
        listener: (context, state) {
          if (state is RegisterSuccess) {
            // The backend already returned a live session — the patient
            // goes straight to profile setup (no second login), then to
            // "add your first medication". Caregivers land on login.
            if (state.role == 'PATIENT') {
              context.go(Routes.profileSetup);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(context.tr('register.success'))));
              context.go(Routes.login);
            }
          }
        },
        builder: (context, state) {
          final cubit = context.read<RegisterCubit>();
          return Scaffold(
            appBar: AppBar(
              title: Text(context.tr('register.title')),
              actions: const [LanguageToggle()],
            ),
            body: SafeArea(
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
                      _RoleSelector(
                        selectedRole: cubit.role,
                        patientLabel: context.tr('register.rolePatient'),
                        caregiverLabel: context.tr('register.roleCaregiver'),
                        onSelect: cubit.setRole,
                      ),
                      const SizedBox(height: 20),
                      DefaultFormField(
                          controller: _firstName,
                          label: context.tr('register.firstName'),
                          textInputAction: TextInputAction.next,
                          validator: (v) => (v == null || v.trim().length < 2)
                              ? context.tr('common.required')
                              : null),
                      const SizedBox(height: 16),
                      DefaultFormField(
                          controller: _lastName,
                          label: context.tr('register.lastName'),
                          textInputAction: TextInputAction.next,
                          validator: (v) => (v == null || v.trim().length < 2)
                              ? context.tr('common.required')
                              : null),
                      const SizedBox(height: 16),
                      DefaultFormField(
                          controller: _email,
                          label: context.tr('login.email'),
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: (v) => AppValidators.isValidEmail(v ?? '')
                              ? null
                              : context.tr('register.invalidEmail')),
                      const SizedBox(height: 16),
                      DefaultFormField(
                          controller: _phone,
                          label: context.tr('register.phone'),
                          hint: '01xxxxxxxxx',
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          validator: (v) =>
                              AppValidators.isValidEgyptianPhone(v ?? '')
                                  ? null
                                  : context.tr('login.invalidPhone')),
                      const SizedBox(height: 16),
                      DefaultFormField(
                          controller: _password,
                          label: context.tr('login.password'),
                          prefixIcon: Icons.lock_outline,
                          obscureText: cubit.obscurePassword,
                          textInputAction: TextInputAction.next,
                          suffixIcon: IconButton(
                            tooltip: cubit.obscurePassword
                                ? context.tr('login.showPassword')
                                : context.tr('login.hidePassword'),
                            icon: Icon(
                              cubit.obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            onPressed: cubit.togglePasswordVisibility,
                          ),
                          validator: (v) =>
                              (v == null || v.length < 8) ? context.tr('register.passwordHint') : null),
                      const SizedBox(height: 16),
                      // Confirm password — elderly users typo passwords often;
                      // catching it here avoids a full failed-registration
                      // round-trip to the server.
                      DefaultFormField(
                          controller: _confirmPassword,
                          label: context.tr('register.confirmPassword'),
                          prefixIcon: Icons.lock_outline,
                          obscureText: cubit.obscurePassword,
                          textInputAction: TextInputAction.done,
                          validator: (v) => (v == null || v != _password.text)
                              ? context.tr('err.passwordMismatch')
                              : null),
                      if (state is RegisterError) ...[
                        const SizedBox(height: 12),
                        Text(context.trv(state.message),
                            style: const TextStyle(color: Colors.red)),
                      ],
                      const SizedBox(height: 20),
                      DefaultButton(
                        label: context.tr('register.submit'),
                        loading: state is RegisterLoading,
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            cubit.register(
                              firstName: _firstName.text,
                              lastName: _lastName.text,
                              email: _email.text,
                              password: _password.text,
                              phone: _phone.text,
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(context.tr('register.haveAccount')),
                          TextButton(
                            onPressed: () => context.go(Routes.login),
                            child: Text(context.tr('register.loginLink')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Privacy consent link (store requirement).
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              context.tr('register.privacyAgree'),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => context.push(Routes.privacy),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 12),
                                child: Text(
                                  context.tr('register.privacyLink'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        decoration: TextDecoration.underline,
                                      ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _RoleSelector extends StatelessWidget {
  final String selectedRole;
  final String patientLabel;
  final String caregiverLabel;
  final ValueChanged<String> onSelect;

  const _RoleSelector({
    required this.selectedRole,
    required this.patientLabel,
    required this.caregiverLabel,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget item(String value, String label, IconData icon) {
      final selected = selectedRole == value;
      return Expanded(
        child: Material(
          color: selected ? scheme.secondaryContainer : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onSelect(value),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: selected
                          ? scheme.onSecondaryContainer
                          : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected
                              ? scheme.onSecondaryContainer
                              : scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        item('PATIENT', patientLabel, Icons.person_outline),
        const SizedBox(width: 8),
        item('FAMILY_CAREGIVER', caregiverLabel, Icons.diversity_1_outlined),
      ],
    );
  }
}
