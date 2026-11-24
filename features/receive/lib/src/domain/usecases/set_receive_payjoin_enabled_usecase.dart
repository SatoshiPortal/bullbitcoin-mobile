import 'package:primitives/primitives.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:receive/receive.dart';
import 'package:meta/meta.dart';

typedef SetReceivePayjoinEnabled = Future<Result<bool, Failure>> Function(
  bool enabled, {
  required Future<bool> Function() requestConsent,
});

/// The host owns the shared consent flag used by the Settings and Receive entry points.
class SetReceivePayjoinEnabledUsecase {
  final SetReceivePayjoinEnabled _setEnabled;

  const SetReceivePayjoinEnabledUsecase(this._setEnabled);

  @useResult
  Future<Result<bool, ReceiveFailure>> execute(
    bool enabled, {
    required Future<bool> Function() requestConsent,
  }) async {
    final result = await _setEnabled(enabled, requestConsent: requestConsent);
    return result.mapErr((failure) {
      log.warning('Failed to toggle payjoin: ${failure.logMessage}');
      return ReceivePayjoinSettingFailure(failure.logMessage);
    });
  }
}
