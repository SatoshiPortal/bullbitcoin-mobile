import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/receive/domain/receive_failure.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:meta/meta.dart';

/// Receive-owned wrapper around the settings feature's public contract.
class SetReceivePayjoinEnabledUsecase {
  final SettingsFacade _settingsFacade;

  SetReceivePayjoinEnabledUsecase({required this._settingsFacade});

  @useResult
  Future<Result<bool, ReceiveFailure>> execute(
    bool enabled, {
    required Future<bool> Function() requestConsent,
  }) async {
    final result = await _settingsFacade.setPayjoinEnabled(
      enabled,
      requestConsent: requestConsent,
    );
    return result.mapErr(
      (failure) => ReceivePayjoinSettingFailure(failure.logMessage),
    );
  }
}
