import 'package:bull_logger/bull_logger.dart';
import 'package:electrum/electrum.dart';
import 'package:primitives/primitives.dart';

/// Persists either explicit advanced settings or the domain-validation change
/// that accompanies switching between default and custom servers.
class UpdateElectrumSettingsUsecase {
  final SetAdvancedElectrumOptionsUsecase _saveOptions;

  const UpdateElectrumSettingsUsecase(this._saveOptions);

  Future<Result<ElectrumSettingsDto, AdvancedOptionsFailure>> execute(
    ElectrumSettingsDto options,
  ) async {
    return switch (await _saveOptions.execute(
      SetAdvancedElectrumOptionsRequest(options: options),
    )) {
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

Future<ElectrumSettingsDto?> syncElectrumDomainValidation({
  required UpdateElectrumSettingsUsecase updateSettings,
  required ElectrumSettingsDto? current,
  required bool validateDomain,
}) async {
  if (current == null || current.validateDomain == validateDomain) return null;
  final updated = ElectrumSettingsDto(
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
