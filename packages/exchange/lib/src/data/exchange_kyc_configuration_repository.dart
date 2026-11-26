import 'package:bull_logger/bull_logger.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

import '../domain/exchange_kyc_configuration.dart';
import '../domain/exchange_failure.dart';

typedef ExchangeKycSetup = ({
  Uri mainnetUrl,
  Uri testnetUrl,
  ExchangeTestnetBasicAuthPreferences preferences,
});

final class ExchangeKycConfigurationRepository {
  final ExchangeKycSetup _setup;

  const ExchangeKycConfigurationRepository(this._setup);

  Future<Result<ExchangeKycConfiguration, ExchangeFailure>> load() async {
    try {
      switch (await _setup.preferences.readExchangeWebPreferences()) {
        case Err():
          log.warning('Could not load exchange web settings: preferences');
          return const Err(ExchangeUnexpectedFailure());
        case Ok(:final value):
          final network = switch (value.environment) {
            Environment.mainnet => BitcoinNetwork.mainnet,
            Environment.testnet => BitcoinNetwork.testnet,
            Environment.regtest => BitcoinNetwork.regtest,
          };
          if (!NetworkCapabilities.supports(
            network,
            NetworkCapability.exchange,
          )) {
            return const Err(ExchangeUnsupportedNetworkFailure());
          }
          final isTestnet = value.environment == Environment.testnet;
          final username = value.exchangeTestnetBasicAuthUsername;
          final password = value.exchangeTestnetBasicAuthPassword;
          return Ok((
            url: isTestnet ? _setup.testnetUrl : _setup.mainnetUrl,
            basicAuth: isTestnet && username != null && password != null
                ? (username: username, password: password)
                : null,
          ));
      }
    } on Exception catch (exception, trace) {
      log.warning(
        'Could not load exchange web settings: ${exception.runtimeType}',
        trace: trace,
      );
      return const Err(ExchangeUnexpectedFailure());
    }
  }
}
