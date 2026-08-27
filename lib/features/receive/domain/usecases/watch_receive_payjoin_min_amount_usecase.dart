import 'package:bb_mobile/features/settings/public/settings_facade.dart';

/// Receive-owned wrapper around the Settings public contract.
class WatchReceivePayjoinMinAmountUsecase {
  final SettingsFacade _settingsFacade;

  WatchReceivePayjoinMinAmountUsecase({required this._settingsFacade});

  Stream<int> execute() => _settingsFacade.watchPayjoinMinAmount();
}
