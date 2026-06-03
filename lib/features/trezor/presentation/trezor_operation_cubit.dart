import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/trezor/application/application_errors.dart';
import 'package:bb_mobile/features/trezor/presentation/trezor_operation_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TrezorOperationCubit extends Cubit<TrezorOperationState> {
  TrezorOperationCubit() : super(const TrezorOperationState());

  /// Runs an async operation that triggers a Trezor Connect deeplink and
  /// awaits the callback. Transitions: launching -> waitingForSuite ->
  /// (success | error).
  Future<void> executeOperation(Future<dynamic> Function() operation) async {
    emit(
      state.copyWith(
        status: TrezorOperationStatus.launching,
        errorMessage: null,
      ),
    );

    try {
      emit(state.copyWith(status: TrezorOperationStatus.waitingForSuite));
      final result = await operation();
      emit(
        state.copyWith(status: TrezorOperationStatus.success, result: result),
      );
    } on TrezorApplicationError catch (e) {
      // Expected paths (user rejected, suite not installed, timeout)
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
      emit(
        state.copyWith(
          status: TrezorOperationStatus.error,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  void reset() => emit(const TrezorOperationState());

  /// Maps an application-layer error to a user-facing message.
  ///
  /// TODO: swap these hardcoded strings for ARB keys
  String _messageFor(TrezorApplicationError e) => switch (e) {
    TrezorUserRejected() => 'Request rejected in Trezor Suite',
    TrezorSuiteNotInstalled() =>
      'Trezor Suite is not installed. Install it from the App Store or Play Store to continue.',
    TrezorTimeout() => 'Timed out waiting for Trezor Suite. Try again.',
    TrezorAddressMismatch() =>
      'Address mismatch — Trezor displayed a different address. Do not use this address.',
    TrezorUnknown(:final message) => message,
  };
}
