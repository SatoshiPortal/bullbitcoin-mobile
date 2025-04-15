import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';

class GetAllElectrumServers {
  final ElectrumServerRepository _electrumServerRepository;
  final SettingsRepository _settingsRepository;
  GetAllElectrumServers({
    required ElectrumServerRepository electrumServerRepository,
    required SettingsRepository settingsRepository,
  })  : _settingsRepository = settingsRepository,
        _electrumServerRepository = electrumServerRepository;

  Future<List<ElectrumServer>> execute({required bool checkStatus}) async {
    final environment = await _settingsRepository.getEnvironment();
    final servers = await _electrumServerRepository.getElectrumServers(
      checkStatus: checkStatus,
      network: Network.fromEnvironment(
        isTestnet: environment.isTestnet,
        isLiquid: false,
      ),
    );
    return servers;
  }
}
