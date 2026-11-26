import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_strings.dart';
import '../../../models/profile_model.dart';
import '../../../shared/components/components.dart';
import '../../../shared/network/local/cache_helper.dart';
import '../../../shared/styles/colors.dart';
import '../../../shared/utils/validators.dart';
import '../cubit/settings_cubit.dart';
import '../cubit/settings_states.dart';

/// User profile card + validated edit profile bottom sheet.
class SettingsProfileCard extends StatelessWidget {
  final SettingsState state;
  final bool isPatient;

  const SettingsProfileCard({
    super.key,
    required this.state,
    required this.isPatient,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SettingsCubit>();
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF5EEAD4)
                      : AppColors.primary)
                  .withValues(alpha: 0.14),
              child: Text(
                (state.profile?.firstName.isNotEmpty ?? false)
                    ? state.profile!.firstName.substring(0, 1)
                    : '👤',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF5EEAD4)
                      : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              state.profile?.fullName.isNotEmpty ?? false
                  ? state.profile!.fullName
                  : '-',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(CacheHelper.getEmail() ?? '-',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            if (state.profileLoading)
              const Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              TextButton.icon(
                onPressed: () => _openEditProfile(
                    context, cubit, isPatient: isPatient, profile: state.profile),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(context.tr('settings.editProfile')),
              ),
          ],
        ),
      ),
    );
  }

  void _openEditProfile(
    BuildContext context,
    SettingsCubit cubit, {
    required bool isPatient,
    ProfileModel? profile,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _EditProfileSheet(
          cubit: cubit,
          isPatient: isPatient,
          profile: profile,
        ),
      ),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  final SettingsCubit cubit;
  final bool isPatient;
  final ProfileModel? profile;

  const _EditProfileSheet({
    required this.cubit,
    required this.isPatient,
    this.profile,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _phone;
  late final TextEditingController _emergencyName;
  late final TextEditingController _emergencyPhone;
  String? _bloodType;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _firstName = TextEditingController(text: p?.firstName ?? '');
    _lastName = TextEditingController(text: p?.lastName ?? '');
    _phone = TextEditingController(text: p?.phone ?? '');
    _emergencyName = TextEditingController(text: p?.emergencyName ?? '');
    _emergencyPhone = TextEditingController(text: p?.emergencyPhone ?? '');
    _bloodType = (p?.bloodType != null && p!.bloodType!.isNotEmpty)
        ? p.bloodType
        : null;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _emergencyName.dispose();
    _emergencyPhone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.tr('settings.editProfile'),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              DefaultFormField(
                controller: _firstName,
                label: context.tr('settings.firstName'),
                prefixIcon: Icons.person_outline,
                validator: (v) => (v == null || v.trim().length < 2)
                    ? context.tr('common.required')
                    : null,
              ),
              const SizedBox(height: 12),
              DefaultFormField(
                controller: _lastName,
                label: context.tr('settings.lastName'),
                prefixIcon: Icons.person_outline,
                validator: (v) => (v == null || v.trim().length < 2)
                    ? context.tr('common.required')
                    : null,
              ),
              const SizedBox(height: 12),
              DefaultFormField(
                controller: _phone,
                label: context.tr('settings.phone'),
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  return AppValidators.isValidEgyptianPhone(v)
                      ? null
                      : context.tr('login.invalidPhone');
                },
              ),
              if (widget.isPatient) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _bloodType,
                  decoration: InputDecoration(
                      labelText: context.tr('settings.bloodType')),
                  items: const [
                    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
                  ]
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => _bloodType = v),
                ),
                const SizedBox(height: 12),
                DefaultFormField(
                  controller: _emergencyName,
                  label: context.tr('settings.emergencyName'),
                  prefixIcon: Icons.emergency,
                ),
                const SizedBox(height: 12),
                DefaultFormField(
                  controller: _emergencyPhone,
                  label: context.tr('settings.emergencyPhone'),
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    return AppValidators.isValidEgyptianPhone(v)
                        ? null
                        : context.tr('login.invalidPhone');
                  },
                ),
              ],
              const SizedBox(height: 16),
              BlocBuilder<SettingsCubit, SettingsState>(
                builder: (_, s) => DefaultButton(
                  label: context.tr('common.save'),
                  loading: s.profileSaving,
                  onPressed: () {
                    if (!_formKey.currentState!.validate()) return;
                    widget.cubit.saveProfile(
                      firstName: _firstName.text.trim(),
                      lastName: _lastName.text.trim(),
                      phone: _phone.text.trim(),
                      bloodType: _bloodType,
                      emergencyName: _emergencyName.text.trim(),
                      emergencyPhone: _emergencyPhone.text.trim(),
                    );
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
