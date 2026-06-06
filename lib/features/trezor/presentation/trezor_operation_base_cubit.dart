import 'dart:async';

import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/trezor/application/application_errors.dart';
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
    log.warning(
      'Trezor operation: app resumed without callback after '
      '$_resumeGracePeriod — treating as launch failure or '
      'user-abandoned (Suite did not respond)',
    );
    emit(
      state.copyWith(
        status: TrezorOperationStatus.error,
        errorMessage: _messageFor(
          const TrezorApplicationError.suiteUnresponsive(),
        ),
      ),
    );
  }

  Future<void> runOperation(Future<T> Function() operation) async {
    if (isClosed) return;
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

      if (isClosed) return;
      _cancelGrace();
      emit(
        state.copyWith(status: TrezorOperationStatus.success, result: result),
      );
    } on TrezorApplicationError catch (e) {
      if (isClosed) return;
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
      if (isClosed) return;
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

  /// Maps an application-layer error to a user-facing message.
  ///
  /// TODO: swap these hardcoded strings for ARB keys
  String _messageFor(TrezorApplicationError e) => switch (e) {
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
