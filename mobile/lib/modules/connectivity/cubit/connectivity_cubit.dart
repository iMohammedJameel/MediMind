import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../services/offline_sync_service.dart';
import 'connectivity_states.dart';

class ConnectivityCubit extends Cubit<ConnectivityState> {
  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _dismissTimer;

  ConnectivityCubit({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity(),
        super(const ConnectivityState(
          status: ConnectivityStatus.online,
          isInitial: true,
        )) {
    _init();
  }

  Future<void> _init() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final isOnline = _isResultsOnline(results);
      emit(ConnectivityState(
        status: isOnline ? ConnectivityStatus.online : ConnectivityStatus.offline,
        isInitial: false,
        showRestoredBanner: false,
      ));
    } catch (_) {}

    _subscription = _connectivity.onConnectivityChanged.listen(_handleResults);
  }

  void _handleResults(List<ConnectivityResult> results) {
    final isOnline = _isResultsOnline(results);
    final prevStatus = state.status;
    final newStatus =
        isOnline ? ConnectivityStatus.online : ConnectivityStatus.offline;

    if (prevStatus == newStatus && !state.isInitial) return;

    if (prevStatus == ConnectivityStatus.offline &&
        newStatus == ConnectivityStatus.online) {
      // Offline -> Online transition: flush sync queue and show cheerful banner
      OfflineSyncService.instance.syncPendingActions();

      _dismissTimer?.cancel();
      emit(state.copyWith(
        status: ConnectivityStatus.online,
        isInitial: false,
        showRestoredBanner: true,
      ));

      _dismissTimer = Timer(const Duration(seconds: 4), () {
        if (!isClosed) {
          emit(state.copyWith(
            status: ConnectivityStatus.online,
            showRestoredBanner: false,
          ));
        }
      });
    } else {
      _dismissTimer?.cancel();
      emit(state.copyWith(
        status: newStatus,
        isInitial: false,
        showRestoredBanner: false,
      ));
    }
  }

  bool _isResultsOnline(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet ||
        r == ConnectivityResult.vpn);
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    _dismissTimer?.cancel();
    return super.close();
  }
}
