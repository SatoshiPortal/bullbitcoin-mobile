import 'dart:convert';

import 'package:bb_mobile/core/exchange/data/exchange_api_key_repository_impl.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Storage extends Fake implements KeyValueStorageDatasource<String> {
  String? value;

  @override
  Future<String?> getValue(String key) async => value;
}

class _Logger extends Mock implements Logger {}

void main() {
  setUpAll(() => registerFallbackValue(StackTrace.empty));
  late _Storage storage;
  late _Logger logger;
  late Logger previousLogger;
  late ExchangeApiKeyRepositoryImpl repository;

  Future<String?> readKey() async =>
      switch (await repository.readActiveApiKey(isTestnet: true)) {
        Ok(:final value) => value,
        Err(:final failure) => fail(
          'Unexpected credential failure: ${failure.runtimeType}',
        ),
      };

  setUp(() {
    storage = _Storage();
    logger = _Logger();
    previousLogger = log;
    log = logger;
    repository = ExchangeApiKeyRepositoryImpl(secureStorage: storage);
  });
  tearDown(() => log = previousLogger);

  test('authentication does not require unused account metadata', () async {
    storage.value = jsonEncode({'key': 'synthetic-key', 'isActive': true});
    expect(await readKey(), 'synthetic-key');
  });

  test('inactive credentials are an expected unauthenticated state', () async {
    storage.value = jsonEncode({
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
