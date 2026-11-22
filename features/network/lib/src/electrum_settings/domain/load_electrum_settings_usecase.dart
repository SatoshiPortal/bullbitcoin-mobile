import 'package:electrum/electrum.dart';
import 'package:primitives/primitives.dart';

import 'has_custom_bitcoin_onion_server.dart';

typedef ElectrumSettingsSnapshot = ({
  ElectrumServerChecks data,
  bool hasActiveCustomBitcoinOnionServer,
});

class LoadElectrumSettingsUsecase {
  final ElectrumServers _servers;
  final Future<NetworkEnv> Function() _readEnvironment;

  const LoadElectrumSettingsUsecase(this._servers, this._readEnvironment);

  Future<Result<ElectrumSettingsSnapshot?, ElectrumFailure>> execute({
    required bool isLiquid,
    required bool Function() isCurrent,
    required void Function(ElectrumServerChecks) onUpdate,
  }) async {
    final ElectrumServerNetwork network;
    try {
      network = ElectrumServerNetwork.fromNetworkEnv(
        await _readEnvironment(),
        isLiquid: isLiquid,
      );
    } on ElectrumUnsupportedNetworkException {
      return const Err(ElectrumUnsupportedNetworkFailure());
    } on Exception {
      return const Err(ElectrumLoadFailure());
    }
    if (!isCurrent()) return const Ok(null);

    ElectrumServerChecks? last;
    await for (final result in _servers.watchChecks(network: network)) {
      if (!isCurrent()) return const Ok(null);
      switch (result) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          last = value;
          onUpdate(value);
      }
    }
    if (!isCurrent() || last == null) return const Ok(null);
    return Ok((
      data: last,
      hasActiveCustomBitcoinOnionServer: await hasCustomBitcoinOnionServer(
        _servers,
        network,
      ),
    ));
  }
}
