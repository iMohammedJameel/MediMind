import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app_router.dart';
import '../../../l10n/app_strings.dart';
import '../../../services/notifications_poller.dart';
import '../../../shared/network/local/cache_helper.dart';
import '../../../shared/styles/colors.dart';
import '../../../shared/utils/formatters.dart';

/// Top greeting row with personalized name, date, unread badge and settings.
class TodayHeader extends StatelessWidget {
  const TodayHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final greetingKey = now.hour < 12
        ? 'home.greetingMorning'
        : now.hour < 17
            ? 'home.greetingAfternoon'
            : 'home.greetingEvening';
    final firstName = CacheHelper.getFirstName();
    final greetingText = (firstName != null && firstName.isNotEmpty)
        ? context
            .tr('today.greetingNamed')
            .replaceAll('{greeting}', context.tr(greetingKey))
            .replaceAll('{name}', firstName)
        : context.tr(greetingKey);
    String dateLabel;
    try {
      dateLabel = AppFormatters.date(now, locale: context.lang, withYear: false);
    } catch (_) {
      dateLabel = '${now.day}/${now.month}';
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MediMind • $dateLabel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: dark ? Colors.white70 : AppColors.secondaryText,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .3,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                greetingText,
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: dark ? Colors.white : AppColors.brandText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                context.tr('home.dailyCareSubtitle'),
                style: TextStyle(
                  fontSize: 13,
                  color: dark ? Colors.white60 : AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
        ValueListenableBuilder<int>(
          valueListenable: NotificationsPoller.instance.unread,
          builder: (_, unread, __) => _HeaderIcon(
            icon: Icons.notifications_none_rounded,
            tooltip: context.tr('today.notifications'),
            badge: unread,
            onTap: () => context.push(Routes.notifications),
          ),
        ),
        const SizedBox(width: 8),
        _HeaderIcon(
          icon: Icons.settings_outlined,
          tooltip: context.tr('today.settings'),
          onTap: () => context.push(Routes.settings),
        ),
      ],
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final int badge;

  const _HeaderIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = dark ? const Color(0xFF5EEAD4) : AppColors.primary;
    return Material(
      color: dark
          ? const Color(0xFF172A24).withValues(alpha: .82)
          : Colors.white.withValues(alpha: .55),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: dark
              ? Colors.white.withValues(alpha: .12)
              : Colors.white.withValues(alpha: .8),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                  child: Icon(icon, color: iconColor, semanticLabel: tooltip)),
              if (badge > 0)
                PositionedDirectional(
                  top: 5,
                  end: 5,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(minWidth: 16),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
