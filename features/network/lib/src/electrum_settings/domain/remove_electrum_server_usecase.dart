import 'package:electrum/electrum.dart';
import 'package:primitives/primitives.dart';

import 'electrum_settings_failure.dart';
import 'update_electrum_settings_usecase.dart';

class RemoveElectrumServerUsecase {
  final ElectrumServers _servers;
  final UpdateElectrumSettingsUsecase _updateSettings;

  const RemoveElectrumServerUsecase(this._servers, this._updateSettings);

  Future<
    Result<
      ({ElectrumOptions? options, bool hasActiveCustomBitcoinOnionServer}),
      ElectrumServersFailure
    >
  >
  execute({
    required ElectrumServerNetwork network,
    required ElectrumServerNetwork serverNetwork,
    required String url,
    required bool Function() otherServersRemain,
    required ElectrumOptions? Function() currentOptions,
  }) async {
    if (network != serverNetwork) {
      return const Err(ElectrumServersDeleteFailure());
    }
    switch (await _servers.trash(url, network: network)) {
      case Ok():
        // Read the live list after deletion, as a concurrent add may have
        // completed while the package was deleting this server.
        final options = otherServersRemain()
            ? null
            : await syncElectrumDomainValidation(
                updateSettings: _updateSettings,
                current: currentOptions(),
                validateDomain: true,
              );
        final onion = await _servers.hasActiveCustomBitcoinOnionServer();
        return Ok((
          options: options,
          hasActiveCustomBitcoinOnionServer: onion.fold(
            (value) => value,
            (_) => false,
          ),
        ));
      case Err(:final failure):
        return Err(ElectrumServersDeleteFailure(failure.logMessage));
    }
  }
}
