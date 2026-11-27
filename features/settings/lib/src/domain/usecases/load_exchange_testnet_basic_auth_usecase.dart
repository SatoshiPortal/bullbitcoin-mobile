import 'package:exchange/exchange.dart' show Exchange, ExchangeBasicAuthValues;
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:settings/src/domain/settings_failure.dart';

/// Reads the sandbox Basic Auth from Exchange. A failed read is an error, not
/// an empty credential.
class LoadExchangeTestnetBasicAuthUsecase {
  final Exchange _exchange;

  const LoadExchangeTestnetBasicAuthUsecase({required this._exchange});

  @useResult
  Future<Result<ExchangeBasicAuthValues, SettingsFailure>> execute() async =>
      (await _exchange.readTestnetBasicAuth()).mapErr(
        (failure) => SettingsUnexpectedFailure(failure.logMessage),
      );
}
