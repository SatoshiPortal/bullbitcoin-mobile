import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_url.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';

final class HasActiveCustomBitcoinOnionServerUsecase {
  final ElectrumServerRepository _serverRepository;
  final SettingsRepository _settingsRepository;

  const HasActiveCustomBitcoinOnionServerUsecase(
    this._serverRepository,
    this._settingsRepository,
  );

  Future<bool> execute() async {
    try {
      final settings = await _settingsRepository.fetch();
      final result = await _serverRepository.fetchActiveServers(
        network: ElectrumServerNetwork.fromEnvironment(
          isTestnet: settings.environment.isTestnet,
          isLiquid: false,
        ),
      );
      return result.fold(
        (servers) => servers.any(
          (server) => server.isCustom && ElectrumServerUrl(server.url).isOnion,
        ),
        (_) => false,
      );
    } on Exception {
      return false;
    }
  }
}
