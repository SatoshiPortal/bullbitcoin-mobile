import 'package:exchange/exchange.dart' show Exchange;
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:settings/src/domain/settings_failure.dart';

/// Stores the sandbox Basic Auth through Exchange, its only owner.
class SetExchangeTestnetBasicAuthUsecase {
  final Exchange _exchange;

  const SetExchangeTestnetBasicAuthUsecase({required this._exchange});

  @useResult
  Future<Result<void, SettingsFailure>> execute({
    String? username,
    String? password,
  }) async {
    final result = await _exchange.saveTestnetBasicAuth(
      username: username,
      password: password,
    );

    return result.mapErr(
      (failure) => SettingsStorageFailure(failure.logMessage),
    );
  }
}
