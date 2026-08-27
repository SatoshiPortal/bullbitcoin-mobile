import 'package:bb_mobile/core/electrum/domain/ports/environment_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_environment.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';

class EnvironmentAdapter implements EnvironmentPort {
  final SettingsRepository _settingsRepository;

  EnvironmentAdapter({required this._settingsRepository});

  @override
  Future<ElectrumEnvironment> getEnvironment() async {
    final settings = await _settingsRepository.fetch();
    return settings.environment.isMainnet
        ? ElectrumEnvironment.mainnet
        : ElectrumEnvironment.testnet;
  }
}
