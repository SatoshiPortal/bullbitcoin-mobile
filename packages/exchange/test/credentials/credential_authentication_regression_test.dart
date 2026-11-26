import 'package:exchange/setup.dart';
import 'package:exchange/testing.dart';

import 'dart:convert';

import 'package:primitives/primitives.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Logger extends Mock implements Logger {}

void main() {
  setUpAll(() => registerFallbackValue(StackTrace.empty));
  late InMemoryExchangeCredentialStorage storage;
  late _Logger logger;
  late Logger previousLogger;
  late ExchangeCredentials repository;

  Future<String?> readKey() async =>
      switch (await repository.readActiveApiKey(isTestnet: true)) {
        Ok(:final value) => value,
        Err(:final failure) => fail(
          'Unexpected credential failure: ${failure.runtimeType}',
        ),
      };

  setUp(() {
    storage = InMemoryExchangeCredentialStorage();
    logger = _Logger();
    previousLogger = log;
    log = logger;
    repository = ExchangeCredentials.open(storage);
  });
  tearDown(() => log = previousLogger);

  test('authentication does not require unused account metadata', () async {
    storage.entries['testnet'] = jsonEncode({
      'key': 'synthetic-key',
      'isActive': true,
    });
    expect(await readKey(), 'synthetic-key');
  });

  test('inactive credentials are an expected unauthenticated state', () async {
    storage.entries['testnet'] = jsonEncode({
      'id': 'id',
      'key': 'synthetic-key',
      'name': 'name',
      'userId': 'user',
      'isActive': false,
      'createdAt': 0,
      'updatedAt': 0,
    });
    expect(await readKey(), isNull);
    verifyNever(
      () => logger.severe(
        message: any(named: 'message'),
        error: any(named: 'error'),
        trace: any(named: 'trace'),
      ),
    );
  });
}
