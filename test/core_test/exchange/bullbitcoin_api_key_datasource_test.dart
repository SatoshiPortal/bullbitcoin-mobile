import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSecureStorage extends Mock
    implements KeyValueStorageDatasource<String> {}

void main() {
  late _MockSecureStorage storage;
  late BullbitcoinApiKeyDatasource datasource;

  setUp(() {
    storage = _MockSecureStorage();
    datasource = BullbitcoinApiKeyDatasource(secureStorage: storage);

    when(
      () => storage.saveValue(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(() => storage.deleteValue(any())).thenAnswer((_) async {});
  });

  test(
    'stores and deletes the production scoped credential separately',
    () async {
      await datasource.storeSellToFiatBalanceApiKey(
        'scoped-production-secret',
        isTestnet: false,
      );
      await datasource.deleteSellToFiatBalanceApiKey(isTestnet: false);

      verify(
        () => storage.saveValue(
          key: 'sell_to_fiat_balance_api_key',
          value: 'scoped-production-secret',
        ),
      ).called(1);
      verify(
        () => storage.deleteValue('sell_to_fiat_balance_api_key'),
      ).called(1);
    },
  );

  test('stores and deletes the testnet scoped credential separately', () async {
    await datasource.storeSellToFiatBalanceApiKey(
      'scoped-testnet-secret',
      isTestnet: true,
    );
    await datasource.deleteSellToFiatBalanceApiKey(isTestnet: true);

    verify(
      () => storage.saveValue(
        key: 'sell_to_fiat_balance_api_key_testnet',
        value: 'scoped-testnet-secret',
      ),
    ).called(1);
    verify(
      () => storage.deleteValue('sell_to_fiat_balance_api_key_testnet'),
    ).called(1);
  });
}
