import 'package:electrum/electrum.dart';
import 'package:primitives/primitives.dart';

import 'electrum_settings_failure.dart';
import 'has_custom_bitcoin_onion_server.dart';
import 'update_electrum_settings_usecase.dart';

class AddElectrumServerUsecase {
  final ElectrumServers _servers;
  final UpdateElectrumSettingsUsecase _updateSettings;

  const AddElectrumServerUsecase(this._servers, this._updateSettings);

  Future<
    Result<
      ({
        ElectrumEndpoint server,
        ElectrumServerStatus status,
        ElectrumOptions? options,
        bool hasActiveCustomBitcoinOnionServer,
      }),
      ElectrumServersFailure
    >
  >
  execute({
    required String url,
    required bool enableSsl,
    required ElectrumServerNetwork network,
    required int? lastPriority,
    required ElectrumOptions? Function() currentOptions,
  }) async {
    switch (await _servers.store(
      url,
      network: network,
      priority: (lastPriority ?? -1) + 1,
      enableSsl: enableSsl,
    )) {
      case Ok(:final value):
        // Custom TLS certificates often fail strict domain validation.
        final options = await syncElectrumDomainValidation(
          updateSettings: _updateSettings,
          current: currentOptions(),
          validateDomain: false,
        );
        return Ok((
          server: value,
          status: ElectrumServerStatus.online,
          options: options,
          hasActiveCustomBitcoinOnionServer: await hasCustomBitcoinOnionServer(
            _servers,
            network,
          ),
        ));
      case Err(:final failure):
        final message = failure.logMessage;
        return Err(switch (failure) {
          ElectrumServerAlreadyExistsFailure() =>
            ElectrumServersAlreadyExistsFailure(message),
          ElectrumServerUnreachableFailure() =>
            ElectrumServersUnreachableFailure(message),
          ElectrumExternalTorProxyUnavailableFailure() =>
            ElectrumServersExternalTorProxyUnavailableFailure(message),
          ElectrumUnexpectedFailure() => ElectrumServersUnexpectedFailure(
            message,
          ),
          _ => ElectrumServersAddFailure(message),
        });
    }
  }
}
