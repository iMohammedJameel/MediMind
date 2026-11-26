import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app_router.dart';
import '../../../l10n/app_strings.dart';
import '../../../services/auth_service.dart';
import '../../../services/biometric_service.dart';
import '../../../services/local_notifications_service.dart';
import '../../../shared/components/components.dart';
import '../../../shared/styles/colors.dart';
import '../cubit/settings_cubit.dart';
import '../cubit/settings_states.dart';

/// Notifications, Biometric Security, Crash Reporting, Privacy, Logout & Delete.
class SettingsSecurityAccountCards extends StatefulWidget {
  final SettingsState state;

  const SettingsSecurityAccountCards({super.key, required this.state});

  @override
  State<SettingsSecurityAccountCards> createState() =>
      _SettingsSecurityAccountCardsState();
}

class _SettingsSecurityAccountCardsState
    extends State<SettingsSecurityAccountCards> with WidgetsBindingObserver {
  bool _showExactAlarmPrompt = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshExactAlarmStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshExactAlarmStatus();
    }
  }

  Future<void> _refreshExactAlarmStatus() async {
    final show =
        await LocalNotificationsService.shouldPromptForExactAlarmPermission();
    if (mounted && show != _showExactAlarmPrompt) {
      setState(() => _showExactAlarmPrompt = show);
    }
  }

  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      );

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SettingsCubit>();
    final state = widget.state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context.tr('settings.notifications')),
        GlassCard(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.notifications_active_outlined),
                title: Text(context.tr('settings.notifications')),
                subtitle: Text(context.tr('settings.notificationsHint')),
                value: state.notificationsEnabled,
                onChanged: cubit.setNotificationsEnabled,
              ),
              if (_showExactAlarmPrompt && state.notificationsEnabled)
                ListTile(
                  leading: const Icon(Icons.alarm),
                  title: Text(context.tr('settings.exactAlarms')),
                  subtitle: Text(context.tr('settings.exactAlarmsHint')),
                  onTap: () =>
                      LocalNotificationsService.openExactAlarmSettings(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        FutureBuilder<(bool supported, bool enabled)>(
          future: () async {
            final bio = BiometricService.instance;
            return (await bio.isSupported(), await bio.isEnabled());
          }(),
          builder: (context, snap) {
            final (supported, enabled) = snap.data ?? (false, false);
            if (!supported) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(context.tr('settings.security')),
                GlassCard(
                  child: SwitchListTile(
                    secondary: const Icon(Icons.fingerprint),
                    title: Text(context.tr('settings.biometric')),
                    subtitle: Text(context.tr('settings.biometricHint')),
                    value: enabled,
                    onChanged: (v) async {
                      await BiometricService.instance.setEnabled(v);
                      if (mounted) setState(() {});
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
        GlassCard(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.bug_report_outlined),
                title: Text(context.tr('settings.crashReporting')),
                subtitle: Text(context.tr('settings.crashReportingHint')),
                value: state.crashReportingEnabled,
                onChanged: cubit.setCrashReportingEnabled,
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: Text(context.tr('settings.privacy')),
                trailing:
                    const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () => context.push(Routes.privacy),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GlassCard(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: Text(context.tr('settings.logout'),
                    style: const TextStyle(color: Colors.red)),
                onTap: () => _confirmLogout(context),
              ),
              ListTile(
                leading:
                    const Icon(Icons.delete_forever, color: AppColors.danger),
                title: Text(context.tr('settings.deleteAccount'),
                    style: const TextStyle(color: AppColors.danger)),
                subtitle: Text(context.tr('settings.deleteAccountHint')),
                onTap: () => _confirmDeleteAccount(context, cubit),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('settings.logoutConfirmTitle')),
        content: SingleChildScrollView(
          child: Text(context.tr('settings.logoutConfirmBody')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await AuthService().logout();
              if (context.mounted) context.go(Routes.login);
            },
            child: Text(context.tr('settings.logout')),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, SettingsCubit cubit) {
    showDialog(
      context: context,
      builder: (_) => _DeleteAccountDialog(cubit: cubit, parentContext: context),
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  final SettingsCubit cubit;
  final BuildContext parentContext;

  const _DeleteAccountDialog({
    required this.cubit,
    required this.parentContext,
  });

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('settings.deleteConfirmTitle')),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('settings.deleteConfirmBody')),
              const SizedBox(height: 16),
              DefaultFormField(
                controller: _passwordController,
                label: context.tr('settings.deletePassword'),
                hint: context.tr('settings.deletePasswordHint'),
                prefixIcon: Icons.lock_outline,
                obscureText: true,
                textInputAction: TextInputAction.done,
                validator: (v) => (v == null || v.length < 8)
                    ? context.tr('settings.deletePasswordHint')
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('common.cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () async {
            if (!_formKey.currentState!.validate()) return;
            final password = _passwordController.text;
            Navigator.of(context).pop();
            final deleted = await widget.cubit.deleteAccount(password: password);
            if (deleted && widget.parentContext.mounted) {
              widget.parentContext.go(Routes.login);
            }
          },
          child: Text(context.tr('common.delete')),
        ),
      ],
    );
  }
}
