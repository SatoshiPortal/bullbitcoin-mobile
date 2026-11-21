import '../value_objects/electrum_options.dart';

import 'package:electrum/src/domain/entities/electrum_settings.dart';
import 'package:electrum/src/domain/electrum_failure.dart';
import 'package:electrum/src/domain/errors/electrum_settings_exception.dart';
import 'package:electrum/src/domain/repositories/electrum_settings_repository.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

class SetAdvancedElectrumOptionsUsecase {
  final ElectrumSettingsRepository _electrumSettingsRepository;

  const SetAdvancedElectrumOptionsUsecase({
    required this._electrumSettingsRepository,
  });

  @useResult
  Future<Result<void, ElectrumFailure>> execute(ElectrumOptions options) async {
    // Fetch current settings.
    final ElectrumSettings settings;
    switch (await _electrumSettingsRepository.fetchByNetwork(options.network)) {
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
        newStopGap: options.stopGap,
        newTimeout: options.timeout,
        newRetry: options.retry,
        newValidateDomain: options.validateDomain,
        newSocks5Supplier: () => options.socks5,
      );
      return await _electrumSettingsRepository.save(settings);
    } on InvalidStopGapException catch (e) {
      return Err(ElectrumInvalidStopGapFailure(e.value));
    } on InvalidTimeoutException catch (e) {
      return Err(ElectrumInvalidTimeoutFailure(e.value));
    } on InvalidRetryException catch (e) {
      return Err(ElectrumInvalidRetryFailure(e.value));
    } on Exception {
      log.warning('Failed to set advanced electrum options');
      return const Err(ElectrumUnexpectedFailure());
    }
  }
}
