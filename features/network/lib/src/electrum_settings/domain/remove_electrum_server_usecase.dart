import 'package:electrum/electrum.dart';
import 'package:primitives/primitives.dart';

import 'update_electrum_settings_usecase.dart';

class RemoveElectrumServerUsecase {
  final DeleteCustomServerUsecase _deleteServer;
  final UpdateElectrumSettingsUsecase _updateSettings;
  final HasActiveCustomBitcoinOnionServerUsecase _hasActiveOnionServer;

  const RemoveElectrumServerUsecase(
    this._deleteServer,
    this._updateSettings,
    this._hasActiveOnionServer,
  );

  Future<
    Result<
      ({ElectrumSettingsDto? options, bool hasActiveCustomBitcoinOnionServer}),
      ElectrumServersFailure
    >
  >
  execute({
    required ElectrumServerNetwork network,
    required ElectrumServerNetwork serverNetwork,
    required String url,
    required bool Function() otherServersRemain,
    required ElectrumSettingsDto? Function() currentOptions,
  }) async {
    if (network != serverNetwork) {
      return const Err(ElectrumServersDeleteFailure());
    }
    switch (await _deleteServer.execute(
      DeleteCustomServerRequest(url: url, network: network),
    )) {
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
        return Ok((
          options: options,
          hasActiveCustomBitcoinOnionServer: await _hasActiveOnionServer
              .execute(),
        ));
      case Err(:final failure):
        return Err(ElectrumServersDeleteFailure(failure.logMessage));
    }
  }
}
