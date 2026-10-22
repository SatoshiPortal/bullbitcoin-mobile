import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/exchange/data/http/exchange_authentication_interceptor.dart';
import 'package:bb_mobile/core/exchange/data/exchange_authentication.dart';
import 'package:bb_mobile/core/exchange/data/exchange_api_key_repository_impl.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_api_key_failure.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Storage extends Fake implements KeyValueStorageDatasource<String> {
  final values = <String, String>{};
  Exception? failure;

  @override
  Future<String?> getValue(String key) async {
    final error = failure;
    if (error != null) throw error;
    return values[key];
  }
}

class _Adapter implements HttpClientAdapter {
  final keys = <Object?>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    keys.add(options.headers['X-API-Key']);
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

String _record(String key, {bool active = true}) =>
    jsonEncode({'key': key, 'isActive': active});

void main() {
  test(
    'preserves client options and rereads rotation, environment and logout',
    () async {
      final storage = _Storage();
      final repository = ExchangeApiKeyRepositoryImpl(secureStorage: storage);
      final adapter = _Adapter();
      final mainnet = Dio(
        BaseOptions(
          baseUrl: 'https://example.invalid',
          connectTimeout: const Duration(seconds: 30),
        ),
      )..httpClientAdapter = adapter;
      final testnet = Dio(BaseOptions(baseUrl: 'https://test.invalid'))
        ..httpClientAdapter = adapter;
      addTearDown(() {
        mainnet.close();
        testnet.close();
      });
      addExchangeAuthentication(
        mainnet,
        () => repository.readActiveApiKey(isTestnet: false),
      );
      addExchangeAuthentication(
        testnet,
        () => repository.readActiveApiKey(isTestnet: true),
      );
      storage.values['exchange_api_key'] = _record('main');
      storage.values['exchange_api_key_testnet'] = _record('test');
      await mainnet.get<dynamic>('/probe');
      await testnet.get<dynamic>('/probe');
      storage.values['exchange_api_key'] = _record('rotated');
      await mainnet.get<dynamic>('/probe');
      storage.values.remove('exchange_api_key');
      await expectLater(
        mainnet.get<dynamic>('/probe'),
        throwsA(
          isA<DioException>().having(
            (e) => exchangeAuthenticationException(e)?.isUnauthenticated,
            'signed out',
            true,
          ),
        ),
      );
      expect(adapter.keys, ['main', 'test', 'rotated']);
      expect(mainnet.options.connectTimeout, const Duration(seconds: 30));
      expect(mainnet.options.baseUrl, 'https://example.invalid');
      expect(testnet.options.connectTimeout, isNull);
    },
  );

  test(
    'inactive, corrupt and inaccessible credentials never reach the adapter',
    () async {
      final storage = _Storage();
      final repository = ExchangeApiKeyRepositoryImpl(secureStorage: storage);
      final adapter = _Adapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
        ..httpClientAdapter = adapter;
      addTearDown(dio.close);
      addExchangeAuthentication(
        dio,
        () => repository.readActiveApiKey(isTestnet: true),
      );
      storage.values['exchange_api_key_testnet'] = _record(
        'inactive',
        active: false,
      );
      await expectLater(
        dio.get<dynamic>('/probe'),
        throwsA(
          isA<DioException>().having(
            (e) => exchangeAuthenticationException(e)?.isUnauthenticated,
            'inactive',
            true,
          ),
        ),
      );
      storage.values['exchange_api_key_testnet'] =
          '{"key":"SYNTHETIC-PRIVATE", broken';
      await expectLater(
        dio.get<dynamic>('/probe'),
        throwsA(
          isA<DioException>()
              .having(
                (e) => exchangeAuthenticationException(e)?.failure,
                'invalid',
                isA<ExchangeApiKeyInvalidFailure>(),
              )
              .having(
                (e) => e.toString(),
                'sanitized',
                isNot(contains('SYNTHETIC-PRIVATE')),
              ),
        ),
      );
      storage.failure = Exception('SYNTHETIC-PRIVATE');
      await expectLater(
        dio.get<dynamic>('/probe'),
        throwsA(
          isA<DioException>().having(
            (e) => exchangeAuthenticationException(e)?.failure,
            'unavailable',
            isA<ExchangeApiKeyReadFailure>(),
          ),
        ),
      );
      expect(adapter.keys, isEmpty);
    },
  );

  test(
    'a programmer error completes the request with its original cause',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
        ..httpClientAdapter = _Adapter();
      addTearDown(dio.close);
      addExchangeAuthentication(
        dio,
        () async => throw StateError('programmer bug'),
      );
      await expectLater(
        dio.get<dynamic>('/probe').timeout(const Duration(seconds: 2)),
        throwsA(
          isA<DioException>().having(
            (e) => e.error,
            'cause',
            isA<StateError>(),
          ),
        ),
      );
    },
  );

  test(
    'typed absence and read failure are separate callback outcomes',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
        ..httpClientAdapter = _Adapter();
      addTearDown(dio.close);
      addExchangeAuthentication(
        dio,
        () async => const Err(ExchangeApiKeyReadFailure()),
      );
      await expectLater(
        dio.get<dynamic>('/probe'),
        throwsA(
          isA<DioException>().having(
            (e) => exchangeAuthenticationException(e)?.isUnauthenticated,
            'not a logout',
            false,
          ),
        ),
      );
    },
  );
}
