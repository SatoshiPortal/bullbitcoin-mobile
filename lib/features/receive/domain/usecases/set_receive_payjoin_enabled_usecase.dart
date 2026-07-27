import 'package:bb_mobile/features/settings/public/settings_facade.dart';

/// Receive-owned wrapper around the settings feature's public contract.
class SetReceivePayjoinEnabledUsecase {
  final SettingsFacade _settingsFacade;

  SetReceivePayjoinEnabledUsecase({required this._settingsFacade});

  Future<void> execute(bool enabled) =>
      _settingsFacade.setPayjoinEnabled(enabled);
}
