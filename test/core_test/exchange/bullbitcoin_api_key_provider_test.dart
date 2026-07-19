import 'dart:convert';

import 'package:bb_mobile/core/exchange/data/datasources/http/bullbitcoin_api_key_provider.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSecureStorage extends Mock
    implements KeyValueStorageDatasource<String> {}

void main() {
  late _MockSecureStorage storage;
  late BullbitcoinApiKeyProvider provider;

  setUp(() {
    storage = _MockSecureStorage();
    provider = BullbitcoinApiKeyProvider(secureStorage: storage);
  });

  for (final entry in {
    false: 'exchange_api_key',
    true: 'exchange_api_key_testnet',
  }.entries) {
    test(
      'existing provider reads only the ${entry.key ? 'testnet' : 'production'} broad credential',
      () async {
        when(
          () => storage.getValue(entry.value),
        ).thenAnswer((_) async => jsonEncode(_validBroadApiKey()));

        final apiKey = await provider.getApiKey(isTestnet: entry.key);

        expect(apiKey, 'broad-secret');
        verify(() => storage.getValue(entry.value)).called(1);
        verifyNoMoreInteractions(storage);
      },
    );
  }
}

Map<String, dynamic> _validBroadApiKey() => {
  'id': 'api-key-id',
  'key': 'broad-secret',
  'name': 'Bull Bitcoin Mobile',
  'userId': 'user-id',
  'isActive': true,
  'createdAt': 1,
  'updatedAt': 2,
};
