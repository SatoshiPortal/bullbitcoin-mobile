import 'dart:async';

import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/trezor/domain/trezor_error.dart';
import 'package:bb_mobile/features/trezor/presentation/trezor_operation_state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

abstract class TrezorOperationBaseCubit<T>
    extends Cubit<TrezorOperationState<T>>
    with WidgetsBindingObserver {
  TrezorOperationBaseCubit() : super(TrezorOperationState<T>()) {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Window we give the deeplink callback to arrive after the app
  /// resumes. The trezor_connect package's app_links callback fires
  /// within ~100ms of resume in practice on both iOS and Android.
  /// If we're still in `waitingForSuite` after this much time
  /// post-resume, we conclude the launch didn't reach Suite — most
  /// commonly because Suite isn't installed and the OS handed our
  /// HTTPS deeplink to a browser instead (which returns true from
  /// launchUrl, so we can't detect this via the launchUrl bool
  /// alone).
  static const _resumeGracePeriod = Duration(seconds: 2);

  Timer? _resumeGraceTimer;
  bool _wasBackgrounded = false;

  /// Monotonically increasing counter that identifies the "current" in-flight
  /// operation. Bumped at the start of every [runOperation] call, by
  /// [_onResumeGraceExpired] when the fallback error fires, and by [reset].
  ///
  /// Post-await emits inside [runOperation] check the captured-at-start epoch
  /// against this current value; a mismatch means a fallback (or reset, or
  /// next-operation start) already invalidated the operation, and the late
  /// completion is silently dropped instead of clobbering whatever state
  /// already replaced it.
  int _operationEpoch = 0;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (this.state.status != TrezorOperationStatus.waitingForSuite) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _wasBackgrounded = true;
        _resumeGraceTimer?.cancel();
      case AppLifecycleState.inactive:
        // Transient (notification panel, control center) — ignore.
        break;
      case AppLifecycleState.resumed:
        if (!_wasBackgrounded) break;
        _wasBackgrounded = false;
        _resumeGraceTimer?.cancel();
        _resumeGraceTimer = Timer(_resumeGracePeriod, _onResumeGraceExpired);
      case AppLifecycleState.detached:
        break;
    }
  }

  void _onResumeGraceExpired() {
    if (isClosed) return;
    if (state.status != TrezorOperationStatus.waitingForSuite) return;

    // Bump the epoch — the in-flight runOperation's captured-at-start
    // epoch no longer matches, so its post-await success/error emits are
    // dropped silently. This is what makes "operation resolves after
    // fallback error" not clobber our emitted error.
    _operationEpoch++;

    log.warning(
      'Trezor operation: app resumed without callback after '
      '$_resumeGracePeriod — treating as launch failure or '
      'user-abandoned (Suite did not respond)',
    );
    emit(
      state.copyWith(
        status: TrezorOperationStatus.error,
        errorMessage: _messageFor(
          const TrezorError.suiteUnresponsive(),
        ),
      ),
    );
  }

  Future<void> runOperation(Future<T> Function() operation) async {
    if (isClosed) return;
    // Bump the epoch — this run is now "the current operation." Any earlier
    // in-flight call (left dangling because grace-fallback fired or the user
    // reset between attempts) becomes stale; its post-await emits will be
    // dropped by the epoch checks below.
    final myEpoch = ++_operationEpoch;

    emit(
      state.copyWith(
        status: TrezorOperationStatus.launching,
        errorMessage: null,
      ),
    );

    try {
      if (isClosed) return;
      emit(state.copyWith(status: TrezorOperationStatus.waitingForSuite));

      final result = await operation();

      // Two ways our post-await emit becomes invalid:
      //   1. Cubit was closed mid-await (existing guard).
      //   2. The grace-expiry fallback fired during the await and already
      //      emitted an error state — our `myEpoch` no longer matches the
      //      cubit's current `_operationEpoch`. Late success/error must not
      //      clobber the fallback's error.
      if (isClosed || _operationEpoch != myEpoch) return;
      _cancelGrace();
      emit(
        state.copyWith(status: TrezorOperationStatus.success, result: result),
      );
    } on TrezorError catch (e) {
      if (isClosed || _operationEpoch != myEpoch) return;
      _cancelGrace();
      log.warning('Trezor operation failed', error: e);
      emit(
        state.copyWith(
          status: TrezorOperationStatus.error,
          errorMessage: _messageFor(e),
        ),
      );
      rethrow;
    } catch (e, t) {
      log.severe(
        message: 'Trezor operation unexpected error',
        error: e,
        trace: t,
      );
      if (isClosed || _operationEpoch != myEpoch) return;
      _cancelGrace();
      emit(
        state.copyWith(
          status: TrezorOperationStatus.error,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  void reset() {
    // Bump the epoch so any in-flight operation that resolves after the
    // user taps Try Again doesn't land on the fresh state we're emitting.
    _operationEpoch++;
    _cancelGrace();
    emit(TrezorOperationState<T>());
  }

  void _cancelGrace() {
    _resumeGraceTimer?.cancel();
    _resumeGraceTimer = null;
    _wasBackgrounded = false;
  }

  @override
  Future<void> close() {
    _cancelGrace();
    WidgetsBinding.instance.removeObserver(this);
    return super.close();
  }

  /// Maps a feature error to a user-facing message.
  ///
  /// These strings deliberately stay hardcoded English (matching the
  /// existing Ledger / BitBox cubits in this repo) because the cubit
  /// does not have BuildContext access — localizing requires either
  /// passing context into the cubit (anti-pattern), or restructuring
  /// TrezorOperationState to carry the typed TrezorError itself and
  /// resolving it via context.loc in each screen. The state-shape
  /// refactor is meaningful scope; defer to a follow-up alongside the
  /// same Ledger/BitBox cleanup.
  String _messageFor(TrezorError e) => switch (e) {
    TrezorUserRejected() => 'Request rejected in Trezor Suite',
    TrezorSuiteNotInstalled() =>
      'Trezor Suite is not installed. Install it from the App Store or Play Store to continue.',
    TrezorSuiteUnresponsive() =>
      "Trezor Suite didn't respond. Make sure it's installed, then try again.",
    TrezorTimeout() => 'Timed out waiting for Trezor Suite. Try again.',
    TrezorAddressMismatch() =>
      'Address mismatch — Trezor displayed a different address. Do not use this address.',
    TrezorMissingDescriptor() =>
      'Your Trezor didn\'t return the data needed to import this wallet. '
          'This can happen with older firmware. Update Trezor Suite and your '
          'device firmware to the latest versions, then try again.',
    TrezorUnknown(:final message) => message,
  };
}
