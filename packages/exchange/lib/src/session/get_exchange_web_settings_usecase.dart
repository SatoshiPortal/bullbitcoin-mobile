import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

import '../domain/exchange_basic_auth.dart';
import '../domain/exchange_failure.dart';
import 'read_exchange_environment.dart';

class GetExchangeWebSettingsUsecase {
  final ActiveEnvironmentReader _environment;
  final ExchangeBasicAuthStore _basicAuth;

  GetExchangeWebSettingsUsecase({
    required this._environment,
    required this._basicAuth,
  });

  /// The sandbox credential is read only on testnet. A failed read is reported:
  /// loading the WebView without it would look like a rejected login.
  @useResult
  Future<Result<ExchangeWebPreferences, ExchangeFailure>> execute() async {
    try {
      final Environment environment;
      switch (await _environment.readActiveEnvironment()) {
        case Ok(:final value):
          environment = value;
        case Err():
          log.warning('Could not load exchange web settings: preferences');
          return const Err(ExchangeUnexpectedFailure());
      }
      if (!exchangeNetworkAvailable(environment)) {
        return const Err(ExchangeUnsupportedNetworkFailure());
      }
      if (environment != Environment.testnet) {
        return Ok((
          environment: environment,
          exchangeTestnetBasicAuthUsername: null,
          exchangeTestnetBasicAuthPassword: null,
        ));
      }
      return switch (await _basicAuth.read()) {
        Ok(:final value) => Ok((
          environment: environment,
          exchangeTestnetBasicAuthUsername: value.username,
          exchangeTestnetBasicAuthPassword: value.password,
        )),
        Err(:final failure) => Err(failure),
      };
    } on Exception catch (exception, trace) {
      log.warning(
        'Could not load exchange web settings: ${exception.runtimeType}',
        trace: trace,
      );
      return const Err(ExchangeUnexpectedFailure());
    }
  }
}
