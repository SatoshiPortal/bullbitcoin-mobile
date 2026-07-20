import 'dart:convert';

import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/scoped_api_key_model.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSecureStorage extends Mock
    implements KeyValueStorageDatasource<String> {}

// A well-formed scoped credential value: `bbak-` + 64 lowercase hex chars.
const _scopedKey =
    'bbak-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

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

  for (final entry in {
    false: 'sell_to_fiat_balance_api_key',
    true: 'sell_to_fiat_balance_api_key_testnet',
  }.entries) {
    final environment = entry.key ? 'testnet' : 'production';

    test(
      'stores the $environment scoped credential bound to its userId',
      () async {
        await datasource.storeSellToFiatBalanceApiKey(
          const ScopedApiKeyModel(userId: 'user-id', key: _scopedKey),
          isTestnet: entry.key,
        );

        verify(
          () => storage.saveValue(
            key: entry.value,
            value: jsonEncode({'userId': 'user-id', 'key': _scopedKey}),
          ),
        ).called(1);
      },
    );

    test(
      'reads the $environment scoped credential with its userId binding',
      () async {
        when(() => storage.getValue(entry.value)).thenAnswer(
          (_) async => jsonEncode({'userId': 'user-id', 'key': _scopedKey}),
        );

        final stored = await datasource.getSellToFiatBalanceApiKey(
          isTestnet: entry.key,
        );

        expect(stored?.userId, 'user-id');
        expect(stored?.key, _scopedKey);
      },
    );

    test('deletes the $environment scoped credential separately', () async {
      await datasource.deleteSellToFiatBalanceApiKey(isTestnet: entry.key);

      verify(() => storage.deleteValue(entry.value)).called(1);
    });
  }

  test('returns null when no scoped credential is stored', () async {
    when(
      () => storage.getValue('sell_to_fiat_balance_api_key'),
    ).thenAnswer((_) async => null);

    final stored = await datasource.getSellToFiatBalanceApiKey(
      isTestnet: false,
    );

    expect(stored, isNull);
  });
}
