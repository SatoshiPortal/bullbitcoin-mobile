import 'package:bb_mobile/core/electrum/application/dtos/requests/set_advanced_electrum_options_request.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_settings_repository.dart';

class SetAdvancedElectrumOptionsUsecase {
  final ElectrumSettingsRepository _electrumSettingsRepository;

  const SetAdvancedElectrumOptionsUsecase({
    required ElectrumSettingsRepository electrumSettingsRepository,
  }) : _electrumSettingsRepository = electrumSettingsRepository;

  Future<void> execute(SetAdvancedElectrumOptionsRequest request) async {
    // Fetch current settings, update with new values, and save
    final settings = await _electrumSettingsRepository.fetchByNetwork(
      request.network,
    );
    settings.update(
      newStopGap: request.stopGap,
      newTimeout: request.timeout,
      newRetry: request.retry,
      newValidateDomain: request.validateDomain,
      newSocks5Supplier: () => request.socks5,
      newUseTorProxy: request.useTorProxy,
      newTorProxyPort: request.torProxyPort,
    );
    try {
      await _electrumSettingsRepository.save(settings);
    } catch (e) {
      // If there's an error, rethrow it as a domain-specific exception
      throw Exception('Failed to save advanced Electrum options: $e');
    }
  }
}
