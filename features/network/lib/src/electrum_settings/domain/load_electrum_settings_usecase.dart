import 'package:electrum/electrum.dart';
import 'package:primitives/primitives.dart';

typedef ElectrumSettingsSnapshot = ({
  ElectrumServerChecks data,
  bool hasActiveCustomBitcoinOnionServer,
});

class LoadElectrumSettingsUsecase {
  final ElectrumServers _servers;

  const LoadElectrumSettingsUsecase(this._servers);

  Future<Result<ElectrumSettingsSnapshot?, ElectrumFailure>> execute({
    required bool isLiquid,
    required bool Function() isCurrent,
    required void Function(ElectrumServerChecks) onUpdate,
  }) async {
    final ElectrumServerNetwork network;
    switch (await _servers.activeNetwork(isLiquid: isLiquid)) {
      case Ok(:final value):
        network = value;
      case Err(:final failure):
        return Err(failure);
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
    final onion = await _servers.hasActiveCustomBitcoinOnionServer();
    return Ok((
      data: last,
      hasActiveCustomBitcoinOnionServer: onion.fold(
        (value) => value,
        (_) => false,
      ),
    ));
  }
}
