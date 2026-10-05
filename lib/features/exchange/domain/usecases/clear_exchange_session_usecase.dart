import 'package:bb_mobile/core/exchange/domain/repositories/exchange_api_key_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:bb_mobile/features/exchange/domain/read_exchange_environment.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

/// Drops the stored API key and the webview cookies behind the session.
///
/// Both steps are attempted even if the first fails: leaving cookies behind
/// after a sign-out is the worse outcome. The cookie manager is a platform
/// call with no repository beneath it, so it is caught here.
class ClearExchangeSessionUsecase {
  final ExchangeApiKeyRepository _exchangeApiKeyRepository;
  final SettingsRepository _settingsRepository;
  final Future<void> Function() _clearCookies;

  const ClearExchangeSessionUsecase({
    required this._exchangeApiKeyRepository,
    required this._settingsRepository,
    required this._clearCookies,
  });

  @useResult
  Future<Result<void, ExchangeFailure>> execute() async {
    // Best effort: when the environment cannot be read, the key it would name
    // is unknown, so both keys are deleted rather than neither. The failure is
    // still reported, and the cookies below are cleared either way.
    final ExchangeFailure? failure;
    switch (await readExchangeEnvironment(
      _settingsRepository,
      ExchangeSessionClearFailure.new,
    )) {
      case Err(failure: final envFailure):
        // Each repository call logs its own reason; the environment failure
        // is what gets reported, since the sign-out is incomplete either way.
        await Future.wait([
          _exchangeApiKeyRepository.deleteApiKey(isTestnet: false),
          _exchangeApiKeyRepository.deleteApiKey(isTestnet: true),
        ]);
        failure = envFailure;
      case Ok(value: final environment):
        final deleted = await _exchangeApiKeyRepository.deleteApiKey(
          isTestnet: environment.isTestnet,
        );
        failure = switch (deleted) {
          Ok() => null,
          Err(:final failure) => ExchangeSessionClearFailure(
            failure.logMessage,
          ),
        };
    }

    ExchangeFailure? cookieFailure;
    try {
      await _clearCookies();
    } catch (e, st) {
      log.severe(
        message: 'Failed to clear webview cookies',
        // Type only, matching the repositories: a platform exception can
        // carry request or cookie detail, and logs are uploadable to support.
        error: e.runtimeType,
        trace: st,
      );
      cookieFailure = ExchangeSessionClearFailure(
        'clearCookies failed: ${e.runtimeType}',
      );
    }

    final combined = failure ?? cookieFailure;
    return combined == null ? const Ok(null) : Err(combined);
  }
}
