import 'package:bb_mobile/core/electrum/electrum_facade.dart';
import 'package:bb_mobile/core/swaps/domain/ports/electrum_settings_port.dart';

class ElectrumSettingsAdapter implements ElectrumSettingsPort {
  final ElectrumFacade _electrumFacade;

  ElectrumSettingsAdapter({required ElectrumFacade electrumFacade})
    : _electrumFacade = electrumFacade;

  @override
  Future<SwapElectrumServerConfig?> getPreferredServer({
    required bool isTestnet,
    required bool isLiquid,
  }) async {
    final server = await _electrumFacade.getPreferredServer(
      isTestnet: isTestnet,
      isLiquid: isLiquid,
    );
    if (server == null) {
      return null;
    }
    return SwapElectrumServerConfig(
      url: server.url,
      tls: server.tls,
      validateDomain: server.validateDomain,
      timeout: server.timeout,
    );
  }
}
