import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';
import 'package:synchronized/synchronized.dart';

import '../domain/exchange_basic_auth.dart';
import '../domain/exchange_failure.dart';
import 'storage/exchange_credential_storage.dart';

/// Testnet Basic Auth in the module database. A read failure is reported, not
/// treated as an absent credential.
final class StoredExchangeBasicAuth implements ExchangeBasicAuthStore {
  final ExchangeCredentialStorage _storage;
  final _mutation = Lock();

  StoredExchangeBasicAuth(this._storage);

  @override
  Future<Result<ExchangeBasicAuthValues, ExchangeFailure>> read() async {
    try {
      final values = await _storage.readBasicAuth();
      return Ok((username: values.username, password: values.password));
    } on Exception catch (error) {
      log.warning('Exchange basic auth read failed', error: error.runtimeType);
      return const Err(ExchangeCredentialReadFailure());
    }
  }

  @override
  Future<Result<void, ExchangeFailure>> save({
    String? username,
    String? password,
  }) => _mutation.synchronized(() async {
    try {
      await _storage.writeBasicAuth(username: username, password: password);
      return const Ok(null);
    } on Exception catch (error) {
      log.warning('Exchange basic auth write failed', error: error.runtimeType);
      return const Err(ExchangeBasicAuthSaveFailure());
    }
  });
}
