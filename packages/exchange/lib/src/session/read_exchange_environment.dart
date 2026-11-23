import 'package:primitives/primitives.dart';
import 'package:preferences/preferences.dart';
import 'package:exchange/exchange.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

/// The environment every exchange call is scoped to.
///
/// [onFailure] identifies the operation that could not run.
@useResult
Future<Result<Environment, ExchangeFailure>> readExchangeEnvironment(
  Preferences settingsRepository,
  ExchangeFailure Function([String? logMessage]) onFailure,
) async {
  try {
    final Environment environment;
    switch (await settingsRepository.fetch()) {
      case Ok(value: final settings):
        environment = settings.environment;
      case Err():
        return Err(onFailure('Preferences read failed'));
    }
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
