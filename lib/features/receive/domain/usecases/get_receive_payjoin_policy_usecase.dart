import 'package:bb_mobile/features/settings/public/settings_facade.dart';

class GetReceivePayjoinPolicyUsecase {
  final SettingsFacade _settings;

  const GetReceivePayjoinPolicyUsecase(this._settings);

  Future<({bool enabled, int minimumAmountSat})> execute() =>
      _settings.watchPayjoinPolicy().first;
}
