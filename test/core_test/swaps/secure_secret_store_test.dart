import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/swaps/swaps_adapters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorage extends Mock implements KeyValueStorageDatasource<String> {}

void main() {
  late _MockStorage storage;
  late SecureSecretStore store;

  setUp(() {
    storage = _MockStorage();
    store = SecureSecretStore(storage);
    when(() => storage.getValue(any())).thenAnswer((_) async => 'value');
    when(
      () => storage.saveValue(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(() => storage.deleteValue(any())).thenAnswer((_) async {});
  });

  test('the engine reaches its own swap entries', () async {
    expect(await store.read('swap_master_key_mainnet_f00dbabe'), 'value');
    await store.write('swap_abc', 'blob');
    await store.delete('swap_abc');

    verify(() => storage.saveValue(key: 'swap_abc', value: 'blob')).called(1);
    verify(() => storage.deleteValue('swap_abc')).called(1);
  });

  test('every other keychain entry is out of reach', () {
    for (final key in ['pin', 'seed_f00dbabe', 'exchange_api_key']) {
      expect(() => store.read(key), throwsArgumentError, reason: key);
      expect(() => store.write(key, 'x'), throwsArgumentError, reason: key);
      expect(() => store.delete(key), throwsArgumentError, reason: key);
    }
    verifyNever(() => storage.getValue(any()));
    verifyNever(
      () => storage.saveValue(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    );
    verifyNever(() => storage.deleteValue(any()));
  });
}
