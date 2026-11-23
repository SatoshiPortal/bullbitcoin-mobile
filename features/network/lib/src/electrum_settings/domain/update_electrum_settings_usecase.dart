import 'package:bull_logger/bull_logger.dart';
import 'package:electrum/electrum.dart';
import 'package:primitives/primitives.dart';

import 'electrum_settings_failure.dart';

/// Persists either explicit advanced settings or the domain-validation change
/// that accompanies switching between default and custom servers.
class UpdateElectrumSettingsUsecase {
  final ElectrumServerOptions _options;

  const UpdateElectrumSettingsUsecase(this._options);

  Future<Result<ElectrumOptions, AdvancedOptionsFailure>> execute(
    ElectrumOptions options,
  ) async {
    return switch (await _options.store(options)) {
      Ok() => Ok(options),
      Err(
        failure: ElectrumInvalidStopGapFailure(:final value, :final logMessage),
      ) =>
        Err(AdvancedOptionsInvalidStopGapFailure(value.toString(), logMessage)),
      Err(
        failure: ElectrumInvalidTimeoutFailure(:final value, :final logMessage),
      ) =>
        Err(AdvancedOptionsInvalidTimeoutFailure(value.toString(), logMessage)),
      Err(
        failure: ElectrumInvalidRetryFailure(:final value, :final logMessage),
      ) =>
        Err(AdvancedOptionsInvalidRetryFailure(value.toString(), logMessage)),
      Err(failure: ElectrumSaveFailure(:final logMessage)) => Err(
        AdvancedOptionsSaveFailure(logMessage),
      ),
      Err(:final failure) => Err(
        AdvancedOptionsUnexpectedFailure(failure.logMessage),
      ),
    };
  }
}

Future<ElectrumOptions?> syncElectrumDomainValidation({
  required UpdateElectrumSettingsUsecase updateSettings,
  required ElectrumOptions? current,
  required bool validateDomain,
}) async {
  if (current == null || current.validateDomain == validateDomain) return null;
  final updated = ElectrumOptions(
    retry: current.retry,
    timeout: current.timeout,
    stopGap: current.stopGap,
    validateDomain: validateDomain,
    socks5: current.socks5,
    network: current.network,
  );
  switch (await updateSettings.execute(updated)) {
    case Ok(:final value):
      return value;
    case Err(:final failure):
      log.warning(
        'Failed to auto-toggle validateDomain to $validateDomain',
        error: failure,
      );
      return null;
  }
}
