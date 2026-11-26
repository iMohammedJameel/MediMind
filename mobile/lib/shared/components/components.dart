import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_strings.dart';
import '../../routes.dart';
import '../styles/colors.dart';
import '../utils/formatters.dart';
import '../../modules/settings/cubit/settings_cubit.dart';

/// Reusable app-wide widgets.
class AppComponents {
  AppComponents._();
}

/// Small pill button that flips the app language instantly — placed on every
/// pre-auth screen (onboarding / login / register / forgot password) so an
/// English user is never stuck inside Arabic-only screens before signing in.
///
/// Reads and writes the locale through the app-level [SettingsCubit] which
/// sits above MaterialApp, so the whole tree (incl. RTL direction) rebuilds.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<SettingsCubit>().state.locale;
    final isAr = locale == 'ar';
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Center(
          widthFactor: 1,
          child: Material(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () =>
                  context.read<SettingsCubit>().setLocale(isAr ? 'en' : 'ar'),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.language,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          isAr ? 'English' : 'العربية',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


/// App-wide organic mint background used behind every routed mobile screen.
class MediMindBackground extends StatelessWidget {
  final Widget child;
  const MediMindBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: dark
                  ? const [Color(0xFF10251F), Color(0xFF101A18), Color(0xFF172A24)]
                  : const [Color(0xFFF0F8F3), Color(0xFFF8FBF9), Color(0xFFEAF5EF)],
            ),
          ),
        ),
        Positioned(top: -100, right: -90, child: _BackgroundOrb(color: dark ? const Color(0xFF245B49) : const Color(0xFFB9E2CD), size: 280)),
        Positioned(top: 260, left: -120, child: _BackgroundOrb(color: dark ? const Color(0xFF244C43) : const Color(0xFFD8EDE2), size: 250)),
        Positioned(bottom: 60, right: -95, child: _BackgroundOrb(color: dark ? const Color(0xFF1F493C) : const Color(0xFFC8E5D5), size: 220)),
        child,
      ],
    );
  }
}

class _BackgroundOrb extends StatelessWidget {
  final Color color;
  final double size;
  const _BackgroundOrb({required this.color, required this.size});
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color.withValues(alpha: .72), color.withValues(alpha: .02)]),
      ),
    ),
  );
}

/// Frosted-glass surface for grouping content without losing background depth.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? tint;
  const GlassCard({super.key, required this.child, this.margin = const EdgeInsets.symmetric(vertical: 6), this.padding = const EdgeInsets.all(16), this.radius = 22, this.tint});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          margin: margin,
          decoration: BoxDecoration(
            color: tint ?? (dark ? const Color(0xFF172A24).withValues(alpha: .76) : Colors.white.withValues(alpha: .70)),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: dark ? Colors.white.withValues(alpha: .12) : Colors.white.withValues(alpha: .82)),
            boxShadow: [BoxShadow(color: const Color(0xFF315E4A).withValues(alpha: dark ? .08 : .06), blurRadius: 22, offset: const Offset(0, 7))],
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.circular(radius),
            clipBehavior: Clip.antiAlias,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// Primary full-width button (>=56dp height, elderly-friendly).
class DefaultButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const DefaultButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: AppColors.primary,
      ),
      child: loading
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Text(label),
    );
  }
}

/// Labeled text form field with validator support.
class DefaultFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final bool obscureText;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final Iterable<String>? autofillHints;

  const DefaultFormField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.hint,
    this.onChanged,
    this.textInputAction,
    this.onFieldSubmitted,
    this.autofillHints,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onChanged: onChanged,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      autofillHints: autofillHints,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffixIcon: suffixIcon,
      ),
    );
  }
}

/// Adherence progress ring with the percentage in the middle.
class AdherenceRing extends StatelessWidget {
  final double percent;
  final double size;

  const AdherenceRing({super.key, required this.percent, this.size = 120});

  @override
  Widget build(BuildContext context) {
    final pctText = AppFormatters.digitsForLocale(
      '${(percent.clamp(0, 1) * 100).round()}',
      locale: context.lang,
    );
    return SizedBox(
      height: size,
      width: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            height: size,
            width: size,
            child: CircularProgressIndicator(
              value: percent.clamp(0, 1),
              strokeWidth: 10,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$pctText%',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(context.tr('today.adherence')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Error / retry panel used by every screen's failure state.
class ErrorWithRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorWithRetry({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(context.tr('common.retry')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom navigation shared by patient tabs — modern floating pill bar with
/// animated active tab expansion, crisp icons for all destinations, and smooth transitions.
class PatientBottomNav extends StatelessWidget {
  final int currentIndex;
  const PatientBottomNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = [
      (
        activeIcon: Icons.calendar_today_rounded,
        inactiveIcon: Icons.calendar_today_outlined,
        label: context.tr('nav.today'),
        path: Routes.patientHome,
        index: 0,
      ),
      (
        activeIcon: Icons.medication_rounded,
        inactiveIcon: Icons.medication_outlined,
        label: context.tr('nav.meds'),
        path: Routes.medications,
        index: 1,
      ),
      (
        activeIcon: Icons.insights_rounded,
        inactiveIcon: Icons.insights_outlined,
        label: context.tr('nav.adherence'),
        path: Routes.adherence,
        index: 2,
      ),
      (
        activeIcon: Icons.diversity_1_rounded,
        inactiveIcon: Icons.diversity_1_outlined,
        label: context.tr('nav.circle'),
        path: Routes.careCircle,
        index: 3,
      ),
    ];

    return SafeArea(
      top: false,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E293B).withValues(alpha: .82)
                  : Colors.white.withValues(alpha: .72),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.78),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.07),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                for (final item in items)
                  Expanded(
                    child: _PillNavItem(
                      activeIcon: item.activeIcon,
                      inactiveIcon: item.inactiveIcon,
                      label: item.label,
                      active: item.index == currentIndex,
                      onTap: item.index == currentIndex
                          ? null
                          : () => context.go(item.path),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PillNavItem extends StatelessWidget {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _PillNavItem({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
    required this.active,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor =
        isDark ? const Color(0xFF5EEAD4) : const Color(0xFF174D3F);
    final inactiveColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: primaryColor.withValues(alpha: 0.12),
          highlightColor: primaryColor.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Active Hover/Pill indicator around Icon
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? primaryColor.withValues(alpha: isDark ? 0.25 : 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      active ? activeIcon : inactiveIcon,
                      key: ValueKey<bool>(active),
                      size: 22,
                      color: active ? primaryColor : inactiveColor,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                // Text label ALWAYS visible under icon for all tabs
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    color: active ? primaryColor : inactiveColor,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 11,
                    fontFamily: 'Cairo',
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

