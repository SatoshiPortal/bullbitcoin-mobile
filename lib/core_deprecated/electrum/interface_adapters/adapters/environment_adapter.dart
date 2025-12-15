import 'package:bb_mobile/core_deprecated/electrum/domain/ports/environment_port.dart';
import 'package:bb_mobile/core_deprecated/electrum/domain/value_objects/electrum_environment.dart';
import 'package:bb_mobile/core_deprecated/settings/domain/get_settings_usecase.dart';

class EnvironmentAdapter implements EnvironmentPort {
  final GetSettingsUsecase _getSettingsUsecase;

  EnvironmentAdapter({required GetSettingsUsecase getSettingsUsecase})
    : _getSettingsUsecase = getSettingsUsecase;

  @override
  Future<ElectrumEnvironment> getEnvironment() async {
    final settings = await _getSettingsUsecase.execute();

    final environment = settings.environment;

    if (environment.isMainnet) {
      return ElectrumEnvironment.mainnet;
    } else {
      return ElectrumEnvironment.testnet;
    }
  }
}
