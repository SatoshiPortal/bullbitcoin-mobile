import 'package:electrum/electrum.dart';
import 'package:primitives/primitives.dart';

import 'update_electrum_settings_usecase.dart';

class AddElectrumServerUsecase {
  final AddCustomServerUsecase _addServer;
  final UpdateElectrumSettingsUsecase _updateSettings;
  final HasActiveCustomBitcoinOnionServerUsecase _hasActiveOnionServer;

  const AddElectrumServerUsecase(
    this._addServer,
    this._updateSettings,
    this._hasActiveOnionServer,
  );

  Future<
    Result<
      ({
        ElectrumServerDto server,
        ElectrumServerStatus status,
        ElectrumSettingsDto? options,
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
    required ElectrumSettingsDto? Function() currentOptions,
  }) async {
    final cleanUrl = ElectrumUrlParser.tryParse(url)?.cleanUrl ?? url;
    final server = ElectrumServerDto(
      url: cleanUrl,
      network: network,
      isCustom: true,
      priority: lastPriority == null ? 0 : lastPriority + 1,
      enableSsl: enableSsl,
    );
    switch (await _addServer.execute(AddCustomServerRequest(server: server))) {
      case Ok(:final value):
        // Custom TLS certificates often fail strict domain validation.
        final options = await syncElectrumDomainValidation(
          updateSettings: _updateSettings,
          current: currentOptions(),
          validateDomain: false,
        );
        return Ok((
          server: server,
          status: value,
          options: options,
          hasActiveCustomBitcoinOnionServer: await _hasActiveOnionServer
              .execute(),
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
