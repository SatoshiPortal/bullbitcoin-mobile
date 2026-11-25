import 'package:exchange/exchange.dart';
import 'package:exchange/setup.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:settings/testing.dart';

final class _RefusingStorage extends InMemoryExchangeCredentialStorage {
  @override
  Future<ExchangeBasicAuthValues> readBasicAuth() async =>
      throw Exception('private detail');

  @override
  Future<void> writeBasicAuth({String? username, String? password}) async =>
      throw Exception('private detail');
}

Exchange _exchange(InMemoryExchangeCredentialStorage storage) =>
    exchangeForTesting(basicAuth: ExchangeCredentials.openBasicAuth(storage));

void main() {
  test('the Basic Auth is written to and read from Exchange', () async {
    final storage = InMemoryExchangeCredentialStorage();
    final exchange = _exchange(storage);

    expect(
      await SetExchangeTestnetBasicAuthUsecase(exchange: exchange)
          .execute(username: 'user', password: 'password'),
      isA<Ok<void, SettingsFailure>>(),
    );
    expect((storage.username, storage.password), ('user', 'password'));
    expect(
      await LoadExchangeTestnetBasicAuthUsecase(exchange: exchange).execute(),
      isA<Ok<ExchangeBasicAuthValues, SettingsFailure>>().having(
        (ok) => ok.value,
        'values',
        (username: 'user', password: 'password'),
      ),
    );
  });

  test('a failed read is an error, never an empty credential', () async {
    final result = await LoadExchangeTestnetBasicAuthUsecase(
      exchange: _exchange(_RefusingStorage()),
    ).execute();

    expect(
      result,
      isA<Err<ExchangeBasicAuthValues, SettingsFailure>>().having(
        (err) => err.failure,
        'failure',
        isA<SettingsUnexpectedFailure>(),
      ),
    );
  });

  test('a failed write is reported without its cause', () async {
    final result = await SetExchangeTestnetBasicAuthUsecase(
      exchange: _exchange(_RefusingStorage()),
    ).execute(username: 'user', password: 'password');

    expect(
      result,
      isA<Err<void, SettingsFailure>>().having(
        (err) => err.failure.logMessage,
        'log message',
        isNot(contains('private detail')),
      ),
    );
  });
}
