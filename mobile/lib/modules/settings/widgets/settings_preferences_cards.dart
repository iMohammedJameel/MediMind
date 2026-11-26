import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_strings.dart';
import '../../../shared/components/components.dart';
import '../../../shared/styles/colors.dart';
import '../cubit/settings_cubit.dart';
import '../cubit/settings_states.dart';

/// Appearance (theme mode + language) and Reading & Numerals cards.
class SettingsPreferencesCards extends StatelessWidget {
  final SettingsState state;

  const SettingsPreferencesCards({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SettingsCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context.tr('settings.appearance')),
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      state.themeMode == 'dark'
                          ? Icons.dark_mode_outlined
                          : state.themeMode == 'light'
                              ? Icons.light_mode_outlined
                              : Icons.brightness_auto_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      context.tr('settings.theme'),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _ThemeOptionGlassCard(
                      label: context.tr('settings.theme.light'),
                      icon: Icons.light_mode_rounded,
                      selected: state.themeMode == 'light',
                      onTap: () => cubit.setThemeModeValue('light'),
                    ),
                    const SizedBox(width: 8),
                    _ThemeOptionGlassCard(
                      label: context.tr('settings.theme.dark'),
                      icon: Icons.dark_mode_rounded,
                      selected: state.themeMode == 'dark',
                      onTap: () => cubit.setThemeModeValue('dark'),
                    ),
                    const SizedBox(width: 8),
                    _ThemeOptionGlassCard(
                      label: context.tr('settings.theme.system'),
                      icon: Icons.brightness_auto_rounded,
                      selected: state.themeMode == 'system',
                      onTap: () => cubit.setThemeModeValue('system'),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1),
                ),
                Row(
                  children: [
                    Icon(Icons.language,
                        size: 20, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr('settings.language'),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    segments: [
                      ButtonSegment(
                        value: 'ar',
                        label: Text(context.tr('settings.language.ar')),
                      ),
                      ButtonSegment(
                        value: 'en',
                        label: Text(context.tr('settings.language.en')),
                      ),
                    ],
                    selected: {state.locale},
                    onSelectionChanged: (s) => cubit.setLocale(s.first),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _sectionHeader(context.tr('settings.reading')),
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.schedule_outlined,
                        size: 20, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr('settings.clock'),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        state.use24Hour
                            ? context.tr('settings.clock24')
                            : context.tr('settings.clock12'),
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    segments: [
                      ButtonSegment(
                        value: '12',
                        label: Text(context.tr('settings.clock12')),
                      ),
                      ButtonSegment(
                        value: '24',
                        label: Text(context.tr('settings.clock24')),
                      ),
                    ],
                    selected: {state.use24Hour ? '24' : '12'},
                    onSelectionChanged: (s) =>
                        cubit.setUse24Hour(s.first == '24'),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.translate_outlined),
                  title: Text(context.tr('settings.arabicDigits')),
                  subtitle: Text(context.tr('settings.arabicDigitsHint')),
                  value: state.arabicDigits,
                  onChanged: cubit.setArabicDigits,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1),
                ),
                Row(
                  children: [
                    Icon(Icons.format_size_outlined,
                        size: 20, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr('settings.fontScale'),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '${(state.fontScale * 100).round()}%',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                Slider(
                  value: state.fontScale,
                  min: 1.0,
                  max: 1.4,
                  divisions: 8,
                  label: '${(state.fontScale * 100).round()}%',
                  onChanged: cubit.setFontScale,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.tr('settings.fontNormal'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          context.tr('settings.fontLarge'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          context.tr('settings.fontMax'),
                          textAlign: TextAlign.end,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      );
}

class _ThemeOptionGlassCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOptionGlassCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primary = AppColors.primary;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: selected
                ? (isDark
                    ? primary.withValues(alpha: 0.22)
                    : primary.withValues(alpha: 0.10))
                : (isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.03)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? primary
                  : (isDark
                      ? Colors.white12
                      : Colors.black.withValues(alpha: 0.08)),
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: selected
                    ? primary
                    : (isDark ? Colors.white70 : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? (isDark ? Colors.white : primary)
                      : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
