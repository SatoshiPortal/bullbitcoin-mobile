import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';

/// Receive-owned wrapper around the settings feature's public contract.
class SetReceivePayjoinEnabledUsecase {
  final SettingsFacade _settingsFacade;

  SetReceivePayjoinEnabledUsecase({required this._settingsFacade});

  Future<Result<bool, SettingsFailure>> execute(
    bool enabled, {
    required Future<bool> Function() requestConsent,
  }) => _settingsFacade.setPayjoinEnabled(
    enabled,
    requestConsent: requestConsent,
  );
}
