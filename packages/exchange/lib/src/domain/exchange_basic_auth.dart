import 'package:meta/meta.dart';
import 'package:preferences/preferences.dart' show Environment;
import 'package:primitives/primitives.dart';

import 'exchange_failure.dart';

typedef ExchangeBasicAuthValues = ({String? username, String? password});

/// The settings the Exchange WebViews load: the active network and, on
/// testnet, the sandbox's Basic Auth.
typedef ExchangeWebPreferences = ({
  Environment environment,
  String? exchangeTestnetBasicAuthUsername,
  String? exchangeTestnetBasicAuthPassword,
});

/// Stored testnet Basic Auth of the sandbox.
abstract interface class ExchangeBasicAuthStore {
  @useResult
  Future<Result<ExchangeBasicAuthValues, ExchangeFailure>> read();

  @useResult
  Future<Result<void, ExchangeFailure>> save({
    String? username,
    String? password,
  });
}
