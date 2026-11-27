import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

import '../domain/exchange_basic_auth.dart';
import '../domain/exchange_failure.dart';
import '../domain/exchange_kyc_configuration.dart';

import 'package:preferences/preferences.dart' show Environment;

typedef ExchangeKycSetup = ({Uri mainnetUrl, Uri testnetUrl});

final class ExchangeKycConfigurationRepository {
  final ExchangeKycSetup _setup;
  final Future<Result<ExchangeWebPreferences, ExchangeFailure>> Function()
  _readWebPreferences;

  const ExchangeKycConfigurationRepository(
    this._setup,
    this._readWebPreferences,
  );

  Future<Result<ExchangeKycConfiguration, ExchangeFailure>> load() async {
    try {
      switch (await _readWebPreferences()) {
        case Err(:final failure):
          log.warning(
            'Could not load exchange web settings: ${failure.runtimeType}',
          );
          return Err(failure);
        case Ok(:final value):
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
