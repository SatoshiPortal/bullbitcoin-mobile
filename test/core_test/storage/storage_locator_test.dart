import 'package:bb_mobile/core/storage/storage_locator.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

void main() {
  test('resolves the application store after Secrets registration', () async {
    final storage = FakeSecureStoragePlatform().install();
    final locator = GetIt.asNewInstance();
    addTearDown(locator.reset);
    await StorageLocator.registerDatasources(locator);
    locator.registerSingleton(
      Secrets(scratchDirectory: () async => '/tmp/pr2938-storage-test'),
    );
    final store = locator<KeyValueStorageDatasource<String>>(
      instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
    );
    await store.saveValue(key: 'exchange_test_key', value: 'dummy');
    expect(storage.entries, {'exchange_test_key': 'dummy'});
    expect(await store.getValue('exchange_test_key'), 'dummy');
    expect(await store.hasValue('exchange_test_key'), isTrue);
    await store.deleteValue('exchange_test_key');
    expect(storage.entries, isEmpty);
  });
}
