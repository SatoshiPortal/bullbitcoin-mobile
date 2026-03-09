import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/application/ports/exchange_environment_port.dart';

class SettingsExchangeEnvironmentAdapter implements ExchangeEnvironmentPort {
  // TODO: Once the settings feature is re-arch'ed,
  // use the defined public API/facade instead of the usecase directly
  final GetSettingsUsecase _getSettingsUsecase;

  SettingsExchangeEnvironmentAdapter({
    required GetSettingsUsecase getSettingsUsecase,
  }) : _getSettingsUsecase = getSettingsUsecase;

  @override
  Future<bool> get isTestnet async {
    final settings = await _getSettingsUsecase.execute();
    return settings.environment.isTestnet;
  }
}
