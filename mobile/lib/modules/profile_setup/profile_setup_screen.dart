import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app_router.dart';
import '../../l10n/app_strings.dart';
import '../../services/profile_service.dart';
import '../../shared/components/components.dart';
import '../../shared/styles/colors.dart';

/// Post-registration medical profile step (patients).
///
/// Registration itself no longer fabricates health data (the old flow sent a
/// hardcoded 1990-01-01 / O+ / 70kg / 170cm profile) — the user fills the
/// real values here. Everything is optional and editable later.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _profileService = ProfileService();
  final _emergencyName = TextEditingController();
  final _emergencyPhone = TextEditingController();

  DateTime? _dateOfBirth;
  String? _gender; // 'male' | 'female'
  String? _bloodType;
  bool _saving = false;

  @override
  void dispose() {
    _emergencyName.dispose();
    _emergencyPhone.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 65),
      firstDate: DateTime(now.year - 110),
      lastDate: DateTime(now.year - 12),
      helpText: context.tr('setup.dateOfBirth'),
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final hasEmergency = _emergencyName.text.trim().isNotEmpty ||
          _emergencyPhone.text.trim().isNotEmpty;
      await _profileService.updateProfile({
        if (_dateOfBirth != null)
          'dateOfBirth':
              '${_dateOfBirth!.year.toString().padLeft(4, '0')}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}',
        if (_gender != null) 'gender': _gender,
        if (_bloodType != null && _bloodType!.isNotEmpty)
          'bloodType': _bloodType,
        if (hasEmergency)
          'emergencyContact': {
            if (_emergencyName.text.trim().isNotEmpty)
              'name': _emergencyName.text.trim(),
            if (_emergencyPhone.text.trim().isNotEmpty)
              'phone': _emergencyPhone.text.trim(),
          },
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('setup.saved'))));
      _goNext();
    } catch (_) {
      // Non-blocking: the profile is editable later in Settings — but the
      // user still deserves to KNOW the save failed (it used to fail
      // completely silently).
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('err.profileSave'))));
      _goNext();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _goNext() {
    // Straight to the medications screen — the "add your first medication"
    // onboarding nudge.
    context.go(Routes.medications);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('setup.title')),
        automaticallyImplyLeading: false,
        actions: const [LanguageToggle()],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.tr('setup.subtitle'),
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),

              // ---- Date of birth ----
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _pickDateOfBirth,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: context.tr('setup.dateOfBirth'),
                    prefixIcon: const Icon(Icons.cake_outlined),
                  ),
                  child: Text(
                    _dateOfBirth == null
                        ? '—'
                        : '${_dateOfBirth!.year}/${_dateOfBirth!.month}/${_dateOfBirth!.day}',
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ---- Gender ----
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: Text(context.tr('setup.gender.male')),
                      selected: _gender == 'male',
                      onSelected: (_) => setState(() => _gender = 'male'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: Text(context.tr('setup.gender.female')),
                      selected: _gender == 'female',
                      onSelected: (_) => setState(() => _gender = 'female'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ---- Blood type ----
              DropdownButtonFormField<String>(
                initialValue: _bloodType,
                decoration: InputDecoration(
                  labelText: context.tr('setup.bloodType'),
                  prefixIcon: const Icon(Icons.bloodtype_outlined),
                ),
                items: const ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _bloodType = v),
              ),
              const SizedBox(height: 16),

              // ---- Emergency contact ----
              DefaultFormField(
                controller: _emergencyName,
                label: context.tr('setup.emergencyName'),
                prefixIcon: Icons.contact_phone_outlined,
              ),
              const SizedBox(height: 12),
              DefaultFormField(
                controller: _emergencyPhone,
                label: context.tr('setup.emergencyPhone'),
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 28),

              DefaultButton(
                label: context.tr('setup.save'),
                loading: _saving,
                onPressed: _save,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _saving ? null : _goNext,
                child: Text(context.tr('setup.skip')),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.primary.withValues(alpha: 0.20)
                      : AppColors.mint.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      context.tr('setup.welcome'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(height: 1.6),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
