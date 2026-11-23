import 'package:bb_mobile/features/exchange/domain/read_exchange_environment.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:exchange/exchange.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class GetExchangeWebSettingsUsecase {
  final ExchangeTestnetBasicAuthPreferences _preferences;

  GetExchangeWebSettingsUsecase({required this._preferences});

  @useResult
  Future<Result<ExchangeWebPreferences, ExchangeFailure>> execute() async {
    try {
      final settings = (await _preferences.readExchangeWebPreferences()).fold(
        (value) => value,
        (failure) => throw Exception('Preferences read failed'),
      );
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
