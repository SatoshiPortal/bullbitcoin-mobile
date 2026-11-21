import 'package:electrum/electrum.dart';
import 'package:primitives/primitives.dart' show NetworkEnv;
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';

class EnvironmentAdapter implements EnvironmentPort {
  final SettingsRepository Function() _settingsRepository;

  EnvironmentAdapter({required this._settingsRepository});

  @override
  Future<ElectrumEnvironment> getEnvironment() async {
    final settings = await _settingsRepository().fetch();
    return switch (settings.environment.networkEnv) {
      NetworkEnv.mainnet => ElectrumEnvironment.mainnet,
      NetworkEnv.testnet => ElectrumEnvironment.testnet,
      NetworkEnv.regtest => ElectrumEnvironment.regtest,
      NetworkEnv.signet => throw const ElectrumUnsupportedNetworkException(),
    };
  }

  Future<ElectrumPreferences> readPreferences() async {
    final settings = await _settingsRepository().fetch();
    return (
      isSuperuser: settings.isSuperuser,
      isDevModeEnabled: settings.isDevModeEnabled,
      useTorProxy: settings.useTorProxy,
      torProxyPort: settings.torProxyPort,
    );
  }
}
