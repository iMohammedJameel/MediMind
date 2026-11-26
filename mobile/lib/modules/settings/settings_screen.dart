import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../l10n/app_strings.dart';
import '../../shared/network/local/cache_helper.dart';
import 'cubit/settings_cubit.dart';
import 'cubit/settings_states.dart';
import 'widgets/settings_account_cards.dart';
import 'widgets/settings_preferences_cards.dart';
import 'widgets/settings_profile_card.dart';

/// Full settings: profile (view + edit), appearance, reading prefs,
/// reminders, biometric security, logout, and account deletion (Article 21).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<SettingsCubit>().loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    final isPatient = CacheHelper.getRole() == 'PATIENT';

    return BlocConsumer<SettingsCubit, SettingsState>(
      listener: (context, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(context.trv(state.error!))));
        } else if (state.profileSaved) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.tr('settings.profileSaved'))));
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: Text(context.tr('settings.title'))),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SettingsProfileCard(state: state, isPatient: isPatient),
              const SizedBox(height: 8),
              SettingsPreferencesCards(state: state),
              const SizedBox(height: 8),
              SettingsSecurityAccountCards(state: state),
            ],
          ),
        );
      },
    );
  }
}
