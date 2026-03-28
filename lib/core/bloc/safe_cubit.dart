import 'package:bb_mobile/core/utils/logger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// [Cubit] that avoids throwing when [emit] is called after [close].
///
/// Bloc intentionally throws [StateError] on closed emit so lifecycle bugs stay
/// visible (see https://bloclibrary.dev/migration/#-emit-throws-stateerror-if-bloc-is-closed).
/// We still skip the emit (to avoid crashing / global error handlers), but log a
/// **warning** so you can spot uncancelled subscriptions, async work that
/// outlived the cubit, etc.—not [log.severe], which would imply an app-level failure.
///
/// Prefer cancelling [StreamSubscription]s and similar in [close], and returning
/// early after `await` when side effects should not run after dispose.
abstract class SafeCubit<State> extends Cubit<State> {
  SafeCubit(super.initialState);

  @override
  void emit(State state) {
    if (isClosed) {
      log.warning(
        'Emit ignored: $runtimeType is already closed.',
        trace: StackTrace.current,
      );
      return;
    }
    super.emit(state);
  }
}
