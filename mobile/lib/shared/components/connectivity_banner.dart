import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../l10n/app_strings.dart';
import '../../modules/connectivity/cubit/connectivity_cubit.dart';
import '../../modules/connectivity/cubit/connectivity_states.dart';
import '../../services/offline_sync_service.dart';
import '../styles/colors.dart';

/// Wraps the app and injects a smooth, non-intrusive status banner
/// at the top of the screen whenever the device goes offline, comes back
/// online, or had offline actions permanently dropped during sync.
class ConnectivityBannerWrapper extends StatelessWidget {
  final Widget child;

  const ConnectivityBannerWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectivityCubit, ConnectivityState>(
      builder: (context, state) {
        final isOffline = state.isOffline;
        final showRestored = state.showRestoredBanner;
        final isVisible = isOffline || showRestored;

        return ValueListenableBuilder<int>(
          valueListenable: OfflineSyncService.instance.droppedNotifier,
          builder: (context, dropped, _) {
            return Column(
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: isVisible
                      ? Material(
                          color: showRestored
                              ? AppColors.success
                              : const Color(0xFFE65100),
                          child: SafeArea(
                            bottom: false,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    showRestored
                                        ? Icons.wifi_rounded
                                        : Icons.wifi_off_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      showRestored
                                          ? context.tr('network.onlineBanner')
                                          : context.tr('network.offlineBanner'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Cairo',
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                if (dropped > 0)
                  Material(
                    color: AppColors.danger,
                    child: SafeArea(
                      top: !isVisible,
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.sync_problem_rounded,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                context
                                    .tr('network.syncDropped')
                                    .replaceAll('{count}', '$dropped'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => OfflineSyncService.instance
                                  .resetDroppedCount(),
                              child: Text(context.tr('common.ok')),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Expanded(child: child),
              ],
            );
          },
        );
      },
    );
  }
}
