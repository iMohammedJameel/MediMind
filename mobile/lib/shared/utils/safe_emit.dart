import 'package:flutter_bloc/flutter_bloc.dart';

/// Prevents `StateError: Cannot emit new states after calling close` when an
/// async API call completes after the widget owning this Cubit was disposed.
mixin SafeEmit<S> on Cubit<S> {
  @override
  void emit(S state) {
    if (!isClosed) {
      super.emit(state);
    }
  }
}
