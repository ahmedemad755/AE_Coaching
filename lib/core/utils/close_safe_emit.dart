import 'package:flutter_bloc/flutter_bloc.dart';

/// For a screen's cubit whose work can outlive the screen (a cloud sync
/// that is slow or refused): a state that arrives after the cubit was closed
/// (the user left the screen) is dropped instead of throwing "Cannot emit
/// new states after calling close". The work itself is saved either way;
/// there is just no screen left to show it.
///
/// In a debug build that error also stops the app in the debugger, which
/// freezes it ("isn't responding") while the screen is touched.
mixin CloseSafeEmit<S> on BlocBase<S> {
  @override
  void emit(S state) {
    if (isClosed) return;
    super.emit(state);
  }
}
