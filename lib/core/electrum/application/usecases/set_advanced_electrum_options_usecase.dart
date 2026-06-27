import 'package:bb_mobile/core/electrum/application/dtos/requests/set_advanced_electrum_options_request.dart';
import 'package:bb_mobile/core/electrum/domain/entities/electrum_settings.dart';
import 'package:bb_mobile/core/electrum/domain/errors/electrum_failure.dart';
import 'package:bb_mobile/core/electrum/domain/errors/electrum_settings_exception.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';

class SetAdvancedElectrumOptionsUsecase {
  final ElectrumSettingsRepository _electrumSettingsRepository;

  const SetAdvancedElectrumOptionsUsecase({
    required this._electrumSettingsRepository,
  });

  @useResult
  Future<Result<void, ElectrumFailure>> execute(
    SetAdvancedElectrumOptionsRequest request,
  ) async {
    // Fetch current settings.
    final ElectrumSettings settings;
    switch (await _electrumSettingsRepository.fetchByNetwork(request.network)) {
      case Ok(:final value):
        settings = value;
      case Err(:final failure):
        return Err(failure);
    }

    // The `on Invalid*` arms map expected domain validation (no log). The
    // trailing catch-all keeps the use-case from ever throwing on an
    // unforeseen fault, so the bloc's loading flag is always reset.
    try {
      settings.update(
        newStopGap: request.stopGap,
        newTimeout: request.timeout,
        newRetry: request.retry,
        newValidateDomain: request.validateDomain,
        newSocks5Supplier: () => request.socks5,
      );
      return await _electrumSettingsRepository.save(settings);
    } on InvalidStopGapException catch (e) {
      return Err(ElectrumInvalidStopGapFailure(e.value));
    } on InvalidTimeoutException catch (e) {
      return Err(ElectrumInvalidTimeoutFailure(e.value));
    } on InvalidRetryException catch (e) {
      return Err(ElectrumInvalidRetryFailure(e.value));
    } catch (e, st) {
      log.severe(
        message: 'Failed to set advanced electrum options',
        error: e,
        trace: st,
      );
      return Err(ElectrumUnexpectedFailure(e.toString()));
    }
  }
}
