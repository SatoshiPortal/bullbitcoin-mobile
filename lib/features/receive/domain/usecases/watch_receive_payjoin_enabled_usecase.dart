import 'package:bb_mobile/features/settings/public/settings_facade.dart';

class WatchReceivePayjoinEnabledUsecase {
  final SettingsFacade _settings;

  const WatchReceivePayjoinEnabledUsecase(this._settings);

  Stream<bool> execute() => _settings.watchPayjoinEnabled();
}
