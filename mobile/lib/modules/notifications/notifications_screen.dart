import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/notification_model.dart';
import '../../shared/components/components.dart';
import '../../l10n/app_strings.dart';
import '../../shared/styles/colors.dart';
import '../../shared/utils/formatters.dart';
import 'cubit/notifications_cubit.dart';
import 'cubit/notifications_states.dart';

/// Notifications inbox — shared by patients and caregivers.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => NotificationsCubit()..load(),
      child: const _NotificationsView(),
    );
  }
}

class _NotificationsView extends StatelessWidget {
  const _NotificationsView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationsCubit, NotificationsStates>(
      builder: (context, state) {
        final cubit = context.read<NotificationsCubit>();
        final unread = cubit.items.where((n) => !n.isRead).length;

        return Scaffold(
          appBar: AppBar(
            title: Text(context.tr('notifs.title')),
            centerTitle: true,
            actions: [
              if (unread > 0)
                IconButton(
                  icon: const Icon(Icons.done_all_rounded),
                  tooltip: context.tr('notifs.markAll'),
                  onPressed: cubit.markAllRead,
                ),
            ],
          ),
          body: state is NotificationsLoading
              ? const Center(child: CircularProgressIndicator())
              : state is NotificationsError && cubit.items.isEmpty
                  ? ErrorWithRetry(message: context.trv(state.message), onRetry: cubit.load)
                  : cubit.items.isEmpty
                      ? ListView(children: [
                          const SizedBox(height: 120),
                          const Icon(Icons.notifications_none,
                              size: 64, color: AppColors.textSecondary),
                          const SizedBox(height: 12),
                          Center(child: Text(context.tr('notifs.empty'))),
                        ])
                      : RefreshIndicator(
                          onRefresh: cubit.load,
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            itemCount: cubit.items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) =>
                                _NotificationCard(item: cubit.items[i]),
                          ),
                        ),
        );
      },
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationItem item;
  const _NotificationCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (item.type) {
      String t when item.isMissedDoseAlert =>
        (Icons.warning_amber_rounded, AppColors.danger),
      String t when item.isDoseReminder =>
        (Icons.alarm, AppColors.primary),
      _ => (Icons.notifications_active_outlined, AppColors.info),
    };

    return GlassCard(
      tint: item.isRead ? null : AppColors.primary.withValues(alpha: 0.08),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: item.isRead ? null : () => context.read<NotificationsCubit>().markRead(item.id),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.titleFor(context.lang),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (!item.isRead)
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                                color: AppColors.primary, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(item.messageFor(context.lang),
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    Text(
                      // intl DateFormat with the 'ar' locale crashes unless
                      // initializeDateFormatting('ar') ran — replaced with
                      // the app's dependency-free formatter. The locale now
                      // follows the ACTIVE app language (was hardcoded 'ar').
                      AppFormatters.dateTime(item.createdAt, locale: context.lang),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
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
