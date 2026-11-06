import 'package:bb_mobile/features/electrum_settings/domain/electrum_server_network.dart';
import 'package:primitives/primitives.dart' show NetworkEnv;
import 'package:bb_mobile/core/electrum/domain/ports/environment_port.dart';
import 'package:bb_mobile/features/electrum_settings/domain/electrum_environment.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';

class EnvironmentAdapter implements EnvironmentPort {
  final SettingsRepository _settingsRepository;

  EnvironmentAdapter({required this._settingsRepository});

  @override
  Future<ElectrumEnvironment> getEnvironment() async {
    final settings = await _settingsRepository.fetch();
    return switch (settings.environment.networkEnv) {
      NetworkEnv.mainnet => ElectrumEnvironment.mainnet,
      NetworkEnv.testnet => ElectrumEnvironment.testnet,
      NetworkEnv.regtest => ElectrumEnvironment.regtest,
      NetworkEnv.signet => throw const ElectrumUnsupportedNetworkException(),
    };
  }
}
