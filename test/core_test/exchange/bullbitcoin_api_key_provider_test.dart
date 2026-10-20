import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/exchange/data/datasources/http/authenticated_bullbitcoin_dio_factory.dart';
import 'package:bb_mobile/core/exchange/data/datasources/http/bullbitcoin_api_key_provider.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Storage extends Fake implements KeyValueStorageDatasource<String> {
  final values = <String, String>{};
  final reads = <String>[];
  Exception? failure;

  @override
  Future<String?> getValue(String key) async {
    reads.add(key);
    final error = failure;
    if (error != null) throw error;
    return values[key];
  }
}

class _Logger extends Mock implements Logger {}

class _HttpAdapter implements HttpClientAdapter {
  final apiKeys = <Object?>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    apiKeys.add(options.headers['X-API-Key']);
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

String _record(String key, {bool active = true}) => jsonEncode({
  'id': 'test',
  'key': key,
  'name': 'test',
  'userId': 'test',
  'isActive': active,
  'createdAt': 0,
  'updatedAt': 0,
});

void main() {
  const mainKey = 'exchange_api_key';
  const testKey = 'exchange_api_key_testnet';
  const marker = 'SYNTHETIC-CREDENTIAL-MUST-NOT-BE-LOGGED';
  late _Storage storage;
  late _Logger logger;
  late Logger previousLogger;
  late BullbitcoinApiKeyProvider provider;

  setUpAll(() => registerFallbackValue(StackTrace.empty));
  setUp(() {
    storage = _Storage();
    logger = _Logger();
    previousLogger = log;
    log = logger;
    provider = BullbitcoinApiKeyProvider(secureStorage: storage);
  });
  tearDown(() => log = previousLogger);

  test('reads the selected environment without retaining a key', () async {
    storage.values[mainKey] = _record('main-only');
    storage.values[testKey] = _record('test-only');
    expect(await provider.getApiKey(isTestnet: false), 'main-only');
    expect(await provider.getApiKey(isTestnet: true), 'test-only');
    storage.values[mainKey] = _record('replacement');
    expect(await provider.getApiKey(isTestnet: false), 'replacement');
    storage.values.remove(mainKey);
    expect(await provider.getApiKey(isTestnet: false), isNull);
    expect(storage.reads, [mainKey, testKey, mainKey, mainKey]);
  });

  test(
    'Dio rereads shared credentials and rejects logout before sending',
    () async {
      storage.values[mainKey] = _record('main-only');
      storage.values[testKey] = _record('test-only');
      final adapter = _HttpAdapter();
      final mainnet = AuthenticatedBullBitcoinDioFactory.create(
        isTestnet: false,
        apiKeyProvider: provider,
      )..httpClientAdapter = adapter;
      final testnet = AuthenticatedBullBitcoinDioFactory.create(
        isTestnet: true,
        apiKeyProvider: provider,
      )..httpClientAdapter = adapter;
      addTearDown(() {
        mainnet.close();
        testnet.close();
      });
      await mainnet.get<dynamic>('/test');
      await testnet.get<dynamic>('/test');
      storage.values[mainKey] = _record('replacement');
      await mainnet.get<dynamic>('/test');
      storage.values.remove(mainKey);
      await expectLater(
        mainnet.get<dynamic>('/test'),
        throwsA(isA<DioException>()),
      );
      expect(adapter.apiKeys, ['main-only', 'test-only', 'replacement']);
    },
  );

  test('missing and empty records are unauthenticated', () async {
    expect(await provider.getApiKey(isTestnet: false), isNull);
    storage.values[mainKey] = '';
    expect(await provider.getApiKey(isTestnet: false), isNull);
  });

  test('an inactive key is unauthenticated without a severe log', () async {
    storage.values[mainKey] = _record(marker, active: false);
    expect(await provider.getApiKey(isTestnet: false), isNull);
    verifyNever(
      () => logger.severe(
        message: any(named: 'message'),
        error: any(named: 'error'),
        trace: any(named: 'trace'),
      ),
    );
  });

  test(
    'invalid credential shapes never produce an authorization header',
    () async {
      for (final value in [
        [],
        {'key': 42, 'isActive': true},
        {'key': marker, 'isActive': 'true'},
        {'isActive': true},
      ]) {
        storage.values[mainKey] = jsonEncode(value);
        expect(await provider.getApiKey(isTestnet: false), isNull);
      }
    },
  );

  void expectSanitizedLog() {
    final captured = verify(
      () => logger.severe(
        message: captureAny(named: 'message'),
        error: captureAny(named: 'error'),
        trace: any(named: 'trace'),
      ),
    ).captured;
    expect(captured.map((v) => v.toString()).join(), isNot(contains(marker)));
  }

  test('malformed JSON does not leak its source into logs', () async {
    storage.values[mainKey] = '{"key":"$marker", BROKEN';
    expect(await provider.getApiKey(isTestnet: false), isNull);
    expectSanitizedLog();
  });

  test('storage exceptions do not leak their message into logs', () async {
    storage.failure = Exception(marker);
    expect(await provider.getApiKey(isTestnet: false), isNull);
    expectSanitizedLog();
  });
}
