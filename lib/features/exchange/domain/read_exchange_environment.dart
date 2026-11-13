import 'package:primitives/primitives.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

/// The environment every exchange call is scoped to.
///
/// The shared settings repository still throws, so this is its boundary for
/// the exchange use-cases: they promise a `Result`, and the cubit has no catch
/// left to stop a throw. [onFailure] builds the caller's own variant, so a
/// failed read reads as the operation that could not run, not as a generic
/// error.
@useResult
Future<Result<Environment, ExchangeFailure>> readExchangeEnvironment(
  SettingsRepository settingsRepository,
  ExchangeFailure Function([String? logMessage]) onFailure,
) async {
  try {
    final environment = (await settingsRepository.fetch()).environment;
    if (!exchangeNetworkAvailable(environment)) {
      log.info('Exchange capability unavailable network=${environment.name}');
      return const Err(ExchangeUnsupportedNetworkFailure());
    }
    return Ok(environment);
  } on Exception catch (e, st) {
    // Type only, matching the repositories.
    log.warning('Exchange environment unavailable reason=settings', trace: st);
    return Err(onFailure('settings fetch failed: ${e.runtimeType}'));
  }
}

/// Exchange policy for the active environment; backend readiness is separate.
bool exchangeNetworkAvailable(Environment environment) =>
    NetworkCapabilities.supports(switch (environment) {
      Environment.mainnet => BitcoinNetwork.mainnet,
      Environment.testnet => BitcoinNetwork.testnet,
      Environment.regtest => BitcoinNetwork.regtest,
    }, NetworkCapability.exchange);
