import 'package:electrum/electrum.dart';
import 'package:primitives/primitives.dart';

import 'electrum_settings_failure.dart';

class PrioritizeElectrumServersUsecase {
  final ElectrumServers _servers;

  const PrioritizeElectrumServersUsecase(this._servers);

  Future<
    Result<
      ({
        List<ElectrumEndpoint> servers,
        bool hasActiveCustomBitcoinOnionServer,
      }),
      ElectrumServersFailure
    >
  >
  execute({
    required List<String> urls,
    required ElectrumServerNetwork network,
    required int oldIndex,
    required int newIndex,
  }) async {
    final reordered = [...urls];
    reordered.insert(
      oldIndex < newIndex ? newIndex - 1 : newIndex,
      reordered.removeAt(oldIndex),
    );
    switch (await _servers.prioritize(reordered, network: network)) {
      case Ok(:final value):
        final onion = await _servers.hasActiveCustomBitcoinOnionServer();
        return Ok((
          servers: value,
          hasActiveCustomBitcoinOnionServer: onion.fold(
            (value) => value,
            (_) => false,
          ),
        ));
      case Err(:final failure):
        return Err(ElectrumServersSavePriorityFailure(failure.logMessage));
    }
  }
}
