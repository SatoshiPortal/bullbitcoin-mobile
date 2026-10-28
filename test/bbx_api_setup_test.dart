import 'package:bb_mobile/bbx_api_setup.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bbx_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiKeyDatasource extends Mock
    implements BullbitcoinApiKeyDatasource {}

void main() {
  test('registers a working client per environment', () {
    final locator = GetIt.asNewInstance()
      ..registerSingleton<BullbitcoinApiKeyDatasource>(_MockApiKeyDatasource());

    BbxApiSetup.setup(locator);

    final mainnet = locator<BbxApiDatasource>(
      instanceName: BbxApiDatasource.mainnetInstanceName,
    );
    final testnet = locator<BbxApiDatasource>(
      instanceName: BbxApiDatasource.testnetInstanceName,
    );
    expect(identical(mainnet, testnet), isFalse);
    for (final api in [mainnet, testnet]) {
      expect(api.users, isNotNull);
      expect(api.orders, isNotNull);
      expect(api.prices, isNotNull);
      expect(api.recipients, isNotNull);
      expect(api.messages, isNotNull);
      expect(api.notifications.isConnected, isFalse);
    }
  });
}
