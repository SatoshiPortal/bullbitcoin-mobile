import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

import '../domain/exchange_failure.dart';
import 'read_exchange_environment.dart';

class GetExchangeWebSettingsUsecase {
  final ExchangeTestnetBasicAuthPreferences _preferences;

  GetExchangeWebSettingsUsecase({required this._preferences});

  @useResult
  Future<Result<ExchangeWebPreferences, ExchangeFailure>> execute() async {
    try {
      final ExchangeWebPreferences settings;
      switch (await _preferences.readExchangeWebPreferences()) {
        case Ok(:final value):
          settings = value;
        case Err():
          log.warning('Could not load exchange web settings: preferences');
          return const Err(ExchangeUnexpectedFailure());
      }
      if (!exchangeNetworkAvailable(settings.environment)) {
        return const Err(ExchangeUnsupportedNetworkFailure());
      }
      return Ok(settings);
    } on Exception catch (exception, trace) {
      log.warning(
        'Could not load exchange web settings: ${exception.runtimeType}',
        trace: trace,
      );
      return const Err(ExchangeUnexpectedFailure());
    }
  }
}
