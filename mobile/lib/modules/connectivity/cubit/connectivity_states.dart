import 'package:equatable/equatable.dart';

enum ConnectivityStatus { online, offline }

class ConnectivityState extends Equatable {
  final ConnectivityStatus status;
  final bool isInitial;
  final bool showRestoredBanner;

  const ConnectivityState({
    required this.status,
    this.isInitial = false,
    this.showRestoredBanner = false,
  });

  bool get isOnline => status == ConnectivityStatus.online;
  bool get isOffline => status == ConnectivityStatus.offline;

  ConnectivityState copyWith({
    ConnectivityStatus? status,
    bool? isInitial,
    bool showRestoredBanner = false,
  }) {
    return ConnectivityState(
      status: status ?? this.status,
      isInitial: isInitial ?? this.isInitial,
      showRestoredBanner: showRestoredBanner,
    );
  }

  @override
  List<Object?> get props => [status, isInitial, showRestoredBanner];
}
