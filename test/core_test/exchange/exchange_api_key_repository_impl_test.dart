import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/api_key_model.dart';
import 'package:bb_mobile/core/exchange/data/models/scoped_api_key_model.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_api_key_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBullbitcoinApiKeyDatasource extends Mock
    implements BullbitcoinApiKeyDatasource {}

class _FakeExchangeApiKeyModel extends Fake implements ExchangeApiKeyModel {}

class _FakeScopedApiKeyModel extends Fake implements ScopedApiKeyModel {}

// A well-formed scoped credential value: `bbak-` + 64 lowercase hex chars.
const _scopedKey =
    'bbak-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  late _MockBullbitcoinApiKeyDatasource datasource;
  late ExchangeApiKeyRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(_FakeExchangeApiKeyModel());
    registerFallbackValue(_FakeScopedApiKeyModel());
  });

  setUp(() {
    datasource = _MockBullbitcoinApiKeyDatasource();
    repository = ExchangeApiKeyRepositoryImpl(
      bullbitcoinApiKeyDatasource: datasource,
    );

    when(
      () => datasource.getSellToFiatBalanceApiKey(
        isTestnet: any(named: 'isTestnet'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => datasource.storeSellToFiatBalanceApiKey(
        any(),
        isTestnet: any(named: 'isTestnet'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => datasource.store(any(), isTestnet: any(named: 'isTestnet')),
    ).thenAnswer((_) async {});
    when(
      () => datasource.delete(isTestnet: any(named: 'isTestnet')),
    ).thenAnswer((_) async {});
    when(
      () => datasource.deleteSellToFiatBalanceApiKey(
        isTestnet: any(named: 'isTestnet'),
      ),
    ).thenAnswer((_) async {});
  });

  group('saveApiKey', () {
    for (final isTestnet in [false, true]) {
      test('stores the ordinary key then the valid same-user scoped key '
          '(${isTestnet ? 'testnet' : 'production'})', () async {
        await repository.saveApiKey(_validResponse(), isTestnet: isTestnet);

        verifyInOrder([
          () => datasource.store(
            any(
              that: isA<ExchangeApiKeyModel>()
                  .having((m) => m.key, 'key', 'broad-secret')
                  .having((m) => m.userId, 'userId', 'user-id'),
            ),
            isTestnet: isTestnet,
          ),
          () => datasource.storeSellToFiatBalanceApiKey(
            any(
              that: isA<ScopedApiKeyModel>()
                  .having((m) => m.userId, 'userId', 'user-id')
                  .having((m) => m.key, 'key', _scopedKey),
            ),
            isTestnet: isTestnet,
          ),
        ]);
      });
    }

    test('replaces an existing same-user scoped key', () async {
      when(
        () => datasource.getSellToFiatBalanceApiKey(isTestnet: false),
      ).thenAnswer(
        (_) async => const ScopedApiKeyModel(userId: 'user-id', key: 'old'),
      );

      await repository.saveApiKey(_validResponse(), isTestnet: false);

      verify(() => datasource.store(any(), isTestnet: false)).called(1);
      verify(
        () => datasource.storeSellToFiatBalanceApiKey(any(), isTestnet: false),
      ).called(1);
      // Same user: no removal of the previous scoped key.
      verifyNever(
        () => datasource.deleteSellToFiatBalanceApiKey(isTestnet: false),
      );
    });

    test(
      'preserves an existing same-user scoped key when field absent',
      () async {
        when(
          () => datasource.getSellToFiatBalanceApiKey(isTestnet: false),
        ).thenAnswer(
          (_) async =>
              const ScopedApiKeyModel(userId: 'user-id', key: _scopedKey),
        );

        await repository.saveApiKey({
          'apiKey': _validBroadApiKey(),
        }, isTestnet: false);

        verify(() => datasource.store(any(), isTestnet: false)).called(1);
        verifyNever(
          () =>
              datasource.storeSellToFiatBalanceApiKey(any(), isTestnet: false),
        );
        verifyNever(
          () => datasource.deleteSellToFiatBalanceApiKey(isTestnet: false),
        );
      },
    );

    test(
      'preserves an existing same-user scoped key when field null',
      () async {
        when(
          () => datasource.getSellToFiatBalanceApiKey(isTestnet: false),
        ).thenAnswer(
          (_) async =>
              const ScopedApiKeyModel(userId: 'user-id', key: _scopedKey),
        );

        await repository.saveApiKey({
          'apiKey': _validBroadApiKey(),
          'sellToFiatBalanceApiKey': null,
        }, isTestnet: false);

        verify(() => datasource.store(any(), isTestnet: false)).called(1);
        verifyNever(
          () =>
              datasource.storeSellToFiatBalanceApiKey(any(), isTestnet: false),
        );
      },
    );

    test(
      'does not store a malformed scoped value and preserves existing',
      () async {
        when(
          () => datasource.getSellToFiatBalanceApiKey(isTestnet: false),
        ).thenAnswer(
          (_) async =>
              const ScopedApiKeyModel(userId: 'user-id', key: _scopedKey),
        );

        await repository.saveApiKey({
          'apiKey': _validBroadApiKey(),
          'sellToFiatBalanceApiKey': 'not-a-key',
        }, isTestnet: false);

        verify(() => datasource.store(any(), isTestnet: false)).called(1);
        verifyNever(
          () =>
              datasource.storeSellToFiatBalanceApiKey(any(), isTestnet: false),
        );
        verifyNever(
          () => datasource.deleteSellToFiatBalanceApiKey(isTestnet: false),
        );
      },
    );

    test(
      'removes a different-user scoped key before completing the switch',
      () async {
        when(
          () => datasource.getSellToFiatBalanceApiKey(isTestnet: false),
        ).thenAnswer(
          (_) async =>
              const ScopedApiKeyModel(userId: 'other-user', key: _scopedKey),
        );

        await repository.saveApiKey(_validResponse(), isTestnet: false);

        verifyInOrder([
          () => datasource.deleteSellToFiatBalanceApiKey(isTestnet: false),
          () => datasource.store(any(), isTestnet: false),
          () =>
              datasource.storeSellToFiatBalanceApiKey(any(), isTestnet: false),
        ]);
      },
    );

    test('ordinary login succeeds even when scoped storage fails', () async {
      when(
        () => datasource.storeSellToFiatBalanceApiKey(any(), isTestnet: false),
      ).thenThrow(Exception('scoped storage failure'));

      await repository.saveApiKey(_validResponse(), isTestnet: false);

      verify(() => datasource.store(any(), isTestnet: false)).called(1);
    });

    final invalidResponses = <String, Map<String, dynamic>>{
      'missing broad credential': {'sellToFiatBalanceApiKey': _scopedKey},
      'malformed broad credential': {
        'apiKey': {..._validBroadApiKey(), 'isActive': 'yes'},
        'sellToFiatBalanceApiKey': _scopedKey,
      },
    };

    for (final entry in invalidResponses.entries) {
      test(
        '${entry.key} throws a fixed import error and stores nothing',
        () async {
          await expectLater(
            repository.saveApiKey(entry.value, isTestnet: false),
            throwsA(_fixedImportError),
          );

          verifyNever(() => datasource.store(any(), isTestnet: false));
          verifyNever(
            () => datasource.storeSellToFiatBalanceApiKey(
              any(),
              isTestnet: false,
            ),
          );
        },
      );
    }
  });

  group('deleteApiKey', () {
    test('deletes both credentials on logout', () async {
      await repository.deleteApiKey(isTestnet: true);

      verify(() => datasource.delete(isTestnet: true)).called(1);
      verify(
        () => datasource.deleteSellToFiatBalanceApiKey(isTestnet: true),
      ).called(1);
    });

    test('attempts both credentials when broad deletion fails', () async {
      when(
        () => datasource.delete(isTestnet: true),
      ).thenThrow(Exception('broad deletion failure'));

      await expectLater(
        repository.deleteApiKey(isTestnet: true),
        throwsA(_fixedDeletionError),
      );

      verify(() => datasource.delete(isTestnet: true)).called(1);
      verify(
        () => datasource.deleteSellToFiatBalanceApiKey(isTestnet: true),
      ).called(1);
    });

    test('attempts both credentials when scoped deletion fails', () async {
      when(
        () => datasource.deleteSellToFiatBalanceApiKey(isTestnet: false),
      ).thenThrow(Exception('scoped deletion failure'));

      await expectLater(
        repository.deleteApiKey(isTestnet: false),
        throwsA(_fixedDeletionError),
      );

      verify(() => datasource.delete(isTestnet: false)).called(1);
      verify(
        () => datasource.deleteSellToFiatBalanceApiKey(isTestnet: false),
      ).called(1);
    });
  });

  group('hasApiKey', () {
    test('reports true when a key is stored for the environment', () async {
      when(
        () => datasource.get(isTestnet: false),
      ).thenAnswer((_) async => _FakeExchangeApiKeyModel());

      expect(await repository.hasApiKey(isTestnet: false), isTrue);
      verify(() => datasource.get(isTestnet: false)).called(1);
    });

    test('reports false when no key is stored', () async {
      when(() => datasource.get(isTestnet: true)).thenAnswer((_) async => null);

      expect(await repository.hasApiKey(isTestnet: true), isFalse);
      verify(() => datasource.get(isTestnet: true)).called(1);
    });
  });
}

Map<String, dynamic> _validResponse() => {
  'apiKey': _validBroadApiKey(),
  'sellToFiatBalanceApiKey': _scopedKey,
};

Map<String, dynamic> _validBroadApiKey() => {
  'id': 'api-key-id',
  'key': 'broad-secret',
  'name': 'Bull Bitcoin Mobile',
  'userId': 'user-id',
  'isActive': true,
  'createdAt': 1,
  'updatedAt': 2,
};

final _fixedImportError = isA<Exception>().having(
  (error) => error.toString(),
  'message',
  contains('Unable to import Bull Bitcoin credentials'),
);

final _fixedDeletionError = isA<Exception>().having(
  (error) => error.toString(),
  'message',
  contains('Unable to delete Bull Bitcoin credentials'),
);
