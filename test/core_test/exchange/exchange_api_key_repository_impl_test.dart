import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/api_key_model.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_api_key_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBullbitcoinApiKeyDatasource extends Mock
    implements BullbitcoinApiKeyDatasource {}

class _FakeExchangeApiKeyModel extends Fake implements ExchangeApiKeyModel {}

void main() {
  late _MockBullbitcoinApiKeyDatasource datasource;
  late ExchangeApiKeyRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(_FakeExchangeApiKeyModel());
  });

  setUp(() {
    datasource = _MockBullbitcoinApiKeyDatasource();
    repository = ExchangeApiKeyRepositoryImpl(
      bullbitcoinApiKeyDatasource: datasource,
    );

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

  for (final isTestnet in [false, true]) {
    test(
      'stores scoped then broad credential for ${isTestnet ? 'testnet' : 'production'}',
      () async {
        await repository.saveApiKey(_validResponse(), isTestnet: isTestnet);

        verifyInOrder([
          () => datasource.storeSellToFiatBalanceApiKey(
            'scoped-secret',
            isTestnet: isTestnet,
          ),
          () => datasource.store(
            any(
              that: isA<ExchangeApiKeyModel>()
                  .having((model) => model.key, 'key', 'broad-secret')
                  .having((model) => model.id, 'id', 'api-key-id'),
            ),
            isTestnet: isTestnet,
          ),
        ]);
      },
    );
  }

  final invalidResponses = <String, Map<String, dynamic>>{
    'missing scoped credential': {'apiKey': _validBroadApiKey()},
    'empty scoped credential': {
      'apiKey': _validBroadApiKey(),
      'sellToFiatBalanceApiKey': '   ',
    },
    'missing broad credential': {'sellToFiatBalanceApiKey': 'scoped-secret'},
    'malformed broad credential': {
      'apiKey': {..._validBroadApiKey(), 'isActive': 'yes'},
      'sellToFiatBalanceApiKey': 'scoped-secret',
    },
  };

  for (final entry in invalidResponses.entries) {
    test('${entry.key} performs no storage writes', () async {
      await expectLater(
        repository.saveApiKey(entry.value, isTestnet: false),
        throwsA(_fixedImportError),
      );

      verifyNever(
        () => datasource.storeSellToFiatBalanceApiKey(
          any(),
          isTestnet: any(named: 'isTestnet'),
        ),
      );
      verifyNever(
        () => datasource.store(any(), isTestnet: any(named: 'isTestnet')),
      );
    });
  }

  test('scoped storage failure prevents the broad credential write', () async {
    when(
      () => datasource.storeSellToFiatBalanceApiKey(any(), isTestnet: false),
    ).thenThrow(Exception('storage details scoped-secret'));

    await expectLater(
      repository.saveApiKey(_validResponse(), isTestnet: false),
      throwsA(_fixedImportError),
    );

    verifyNever(
      () => datasource.store(any(), isTestnet: any(named: 'isTestnet')),
    );
  });

  test(
    'broad storage failure leaves the prior scoped write untouched',
    () async {
      when(
        () => datasource.store(any(), isTestnet: false),
      ).thenThrow(Exception('storage details broad-secret'));

      await expectLater(
        repository.saveApiKey(_validResponse(), isTestnet: false),
        throwsA(_fixedImportError),
      );

      verify(
        () => datasource.storeSellToFiatBalanceApiKey(
          'scoped-secret',
          isTestnet: false,
        ),
      ).called(1);
      verifyNever(
        () => datasource.deleteSellToFiatBalanceApiKey(
          isTestnet: any(named: 'isTestnet'),
        ),
      );
    },
  );

  test(
    'deletion attempts both credentials when broad deletion fails',
    () async {
      when(
        () => datasource.delete(isTestnet: true),
      ).thenThrow(Exception('storage details broad-secret'));

      await expectLater(
        repository.deleteApiKey(isTestnet: true),
        throwsA(_fixedDeletionError),
      );

      verify(() => datasource.delete(isTestnet: true)).called(1);
      verify(
        () => datasource.deleteSellToFiatBalanceApiKey(isTestnet: true),
      ).called(1);
    },
  );

  test(
    'deletion attempts both credentials when scoped deletion fails',
    () async {
      when(
        () => datasource.deleteSellToFiatBalanceApiKey(isTestnet: false),
      ).thenThrow(Exception('storage details scoped-secret'));

      await expectLater(
        repository.deleteApiKey(isTestnet: false),
        throwsA(_fixedDeletionError),
      );

      verify(() => datasource.delete(isTestnet: false)).called(1);
      verify(
        () => datasource.deleteSellToFiatBalanceApiKey(isTestnet: false),
      ).called(1);
    },
  );
}

Map<String, dynamic> _validResponse() => {
  'apiKey': _validBroadApiKey(),
  'sellToFiatBalanceApiKey': 'scoped-secret',
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

final _fixedImportError = isA<Exception>()
    .having(
      (error) => error.toString(),
      'message',
      contains('Unable to import Bull Bitcoin credentials'),
    )
    .having((error) => error.toString(), 'secret', isNot(contains('secret')));

final _fixedDeletionError = isA<Exception>()
    .having(
      (error) => error.toString(),
      'message',
      contains('Unable to delete Bull Bitcoin credentials'),
    )
    .having((error) => error.toString(), 'secret', isNot(contains('secret')));
