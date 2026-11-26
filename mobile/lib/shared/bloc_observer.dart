import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Logs every Cubit/Bloc transition & error in DEBUG builds only.
///
/// Production builds stay silent: `print` on every state change floods
/// logcat, leaks business flow (health data navigation patterns) and costs
/// string formatting on the UI thread.
class AppBlocObserver extends BlocObserver {
  @override
  void onCreate(BlocBase bloc) {
    super.onCreate(bloc);
    if (kDebugMode) debugPrint('BLOC CREATED: ${bloc.runtimeType}');
  }

  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    if (kDebugMode) {
      debugPrint('BLOC CHANGE: ${bloc.runtimeType} -> ${change.nextState}');
    }
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    if (kDebugMode) debugPrint('BLOC ERROR: ${bloc.runtimeType} -> $error');
    super.onError(bloc, error, stackTrace);
  }
}
