import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/api_key_model.dart';
import 'package:bb_mobile/core/exchange/data/models/order_model.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_order_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../order_json_fixture.dart';

class _MockApiDatasource extends Mock implements BullbitcoinApiDatasource {}

class _MockApiKeyDatasource extends Mock
    implements BullbitcoinApiKeyDatasource {}

ExchangeApiKeyModel _activeApiKey() => ExchangeApiKeyModel(
  id: 'id',
  key: 'key',
  name: 'name',
  userId: 'user',
  isActive: true,
  createdAt: 0,
  updatedAt: 0,
);

void main() {
  late _MockApiDatasource api;
  late _MockApiKeyDatasource apiKeys;
  late ExchangeOrderRepositoryImpl repository;

  setUp(() {
    api = _MockApiDatasource();
    apiKeys = _MockApiKeyDatasource();
    repository = ExchangeOrderRepositoryImpl(
      bullbitcoinApiDatasource: api,
      bullbitcoinApiKeyDatasource: apiKeys,
      isTestnet: false,
    );
    when(
      () => apiKeys.get(isTestnet: any(named: 'isTestnet')),
    ).thenAnswer((_) async => _activeApiKey());
  });

  void stubOrders(List<Map<String, dynamic>> json) {
    when(
      () => api.listOrderSummaries(apiKey: any(named: 'apiKey')),
    ).thenAnswer((_) async => json.map(OrderModel.fromJson).toList());
  }

  group('getOrders', () {
    test('one order that cannot be mapped no longer empties the list', () async {
      stubOrders([
        orderJsonFixture(orderId: 'good-1'),
        // An unparseable createdAt throws in toEntity, past the JSON layer.
        orderJsonFixture(
          orderId: 'bad-1',
          overrides: const {'createdAt': 'not-a-date'},
        ),
        orderJsonFixture(orderId: 'good-2'),
      ]);

      final orders = await repository.getOrders();

      expect(orders.map((o) => o.orderId), ['good-1', 'good-2']);
    });

    test('an order list containing an Expired order survives intact', () async {
      stubOrders([
        orderJsonFixture(orderId: 'expired-1', orderStatus: 'Expired'),
        orderJsonFixture(orderId: 'good-1'),
        orderJsonFixture(orderId: 'usdt-1', orderType: 'Sell USDT'),
      ]);

      final orders = await repository.getOrders();

      expect(orders.map((o) => o.orderId), ['expired-1', 'good-1', 'usdt-1']);
    });
  });

  group('getOrderByTxId', () {
    test('returns the order whose transaction id matches', () async {
      stubOrders([
        orderJsonFixture(orderId: 'good-1'),
        orderJsonFixture(
          orderId: 'good-2',
          overrides: const {'bitcoinTransactionId': 'txid-2'},
        ),
      ]);

      final order = await repository.getOrderByTxId('txid-2');

      expect(order?.orderId, 'good-2');
    });

    test('returns null when no order matches', () async {
      stubOrders([orderJsonFixture(orderId: 'good-1')]);

      expect(await repository.getOrderByTxId('txid-absent'), isNull);
    });
  });
}
