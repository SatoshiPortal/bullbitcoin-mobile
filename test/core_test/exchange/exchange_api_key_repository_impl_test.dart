import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/api_key_model.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_api_key_repository_impl.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_api_key_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// A realistic auth-app envelope. The key inside is the thing that must never
/// reach a log line or a failure.
const _key = 'bbk_live_7f3a9c2e';
const _apiKeyFields = {
  'id': 'key-1',
  'key': _key,
  'name': 'mobile',
  'userId': 'u-42',
  'isActive': true,
  'createdAt': 1767225600,
  'updatedAt': 1767225600,
};

class _MockApiKeyDatasource extends Mock
    implements BullbitcoinApiKeyDatasource {}

class _FakeApiKeyModel extends Fake implements ExchangeApiKeyModel {}

void main() {
  late _MockApiKeyDatasource datasource;

  ExchangeApiKeyRepositoryImpl build() =>
      ExchangeApiKeyRepositoryImpl(bullbitcoinApiKeyDatasource: datasource);

  setUpAll(() => registerFallbackValue(_FakeApiKeyModel()));

  setUp(() {
    datasource = _MockApiKeyDatasource();
    when(
      () => datasource.store(any(), isTestnet: any(named: 'isTestnet')),
    ).thenAnswer((_) async {});
  });

  group('saveApiKey envelope handling', () {
    // The auth app has shipped several shapes; all must land the same key.
    for (final entry in <String, Map<String, dynamic>>{
      'bare': _apiKeyFields,
      'apiKey-wrapped': {'apiKey': _apiKeyFields},
      'result-wrapped': {
        'result': {'apiKey': _apiKeyFields},
      },
      'data-wrapped': {
        'data': {'apiKey': _apiKeyFields},
      },
    }.entries) {
      test('${entry.key} envelope is accepted', () async {
        expect(
          await build().saveApiKey(entry.value, isTestnet: false),
          isA<Ok<void, ExchangeApiKeyFailure>>(),
          reason: 'the ${entry.key} shape must not be rejected',
        );
      });
    }
  });

  group('saveApiKey failures', () {
    test('a throwing store is sanitized and never echoes the key', () async {
      when(
        () => datasource.store(any(), isTestnet: any(named: 'isTestnet')),
      ).thenThrow(Exception('keychain locked while writing $_key'));

      final result = await build().saveApiKey({
        'apiKey': _apiKeyFields,
      }, isTestnet: false);
      final failure = (result as Err).failure as ExchangeApiKeyFailure;

      expect(failure, isA<ExchangeApiKeySaveFailure>());
      expect(failure.logMessage, isNot(contains(_key)));
    });

    // A malformed envelope used to throw out of the repository; it must be a
    // Result like anything else.
    test('an unparseable payload is a failure, not a throw', () async {
      final result = await build().saveApiKey(const {
        'apiKey': 'not-an-object',
      }, isTestnet: false);

      final failure = (result as Err).failure as ExchangeApiKeyFailure;
      expect(failure, isA<ExchangeApiKeySaveFailure>());
      expect(failure.logMessage, isNot(contains(_key)));
    });
  });

  group('deleteApiKey', () {
    test('a throwing delete is sanitized', () async {
      when(
        () => datasource.delete(isTestnet: any(named: 'isTestnet')),
      ).thenThrow(Exception('keychain locked while deleting $_key'));

      final result = await build().deleteApiKey(isTestnet: false);
      final failure = (result as Err).failure as ExchangeApiKeyFailure;

      expect(failure, isA<ExchangeApiKeyDeleteFailure>());
      expect(failure.logMessage, isNot(contains(_key)));
    });

    test('a clean delete is Ok', () async {
      when(
        () => datasource.delete(isTestnet: any(named: 'isTestnet')),
      ).thenAnswer((_) async {});

      expect(
        await build().deleteApiKey(isTestnet: false),
        isA<Ok<void, ExchangeApiKeyFailure>>(),
      );
    });
  });
}
