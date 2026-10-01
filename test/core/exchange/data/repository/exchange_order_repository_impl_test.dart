import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/api_key_model.dart';
import 'package:bb_mobile/core/exchange/data/models/order_model.dart';
import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_order_repository_impl.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/sepa_payment_processor.dart';
import 'package:bb_mobile/core/exchange/domain/errors/confidential_sepa_not_activated_exception.dart';
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
    test(
      'one order that cannot be mapped no longer empties the list',
      () async {
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
      },
    );

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

  group('the withdraw paths keep the original stack trace', () {
    // The use-case logs the trace it catches. If the repository wrapped the
    // failure with a bare `throw`, every report would point at the catch block
    // instead of the call that actually failed.
    void expectTraceReachesTheFailingCall(StackTrace? trace, String frame) {
      expect(trace, isNotNull);
      expect(
        trace.toString(),
        contains(frame),
        reason: 'the trace no longer reaches the throwing call',
      );
    }

    test('placeWithdrawalOrder', () async {
      when(
        () => api.createWithdrawalOrder(
          apiKey: any(named: 'apiKey'),
          fiatAmount: any(named: 'fiatAmount'),
          recipientId: any(named: 'recipientId'),
          securityQuestion: any(named: 'securityQuestion'),
          securityAnswer: any(named: 'securityAnswer'),
        ),
      ).thenAnswer((_) async => throw StateError('datasource blew up'));

      StackTrace? trace;
      try {
        await repository.placeWithdrawalOrder(
          fiatAmount: 100,
          recipientId: 'recipient-1',
        );
        fail('expected the wrapped exception');
      } catch (_, st) {
        trace = st;
      }

      expectTraceReachesTheFailingCall(trace, 'createWithdrawalOrder');
    });

    test('confirmWithdrawOrder', () async {
      when(
        () => api.confirmOrder(
          apiKey: any(named: 'apiKey'),
          orderId: any(named: 'orderId'),
        ),
      ).thenAnswer((_) async => throw StateError('datasource blew up'));

      StackTrace? trace;
      try {
        await repository.confirmWithdrawOrder('order-1');
        fail('expected the wrapped exception');
      } catch (_, st) {
        trace = st;
      }

      expectTraceReachesTheFailingCall(trace, 'confirmOrder');
    });
  });

  group('confidential SEPA activation errors', () {
    test('preserves the pay datasource exception for the usecase', () async {
      when(
        () => api.createPayOrder(
          apiKey: 'key',
          orderAmount: const FiatAmount(100),
          recipientId: 'recipient-1',
          network: OrderBitcoinNetwork.bitcoin,
          paymentProcessor: SepaPaymentProcessor.confidential,
          usePayjoin: false,
        ),
      ).thenThrow(const ConfidentialSepaNotActivatedApiException());

      expect(
        repository.placePayOrder(
          orderAmount: const FiatAmount(100),
          recipientId: 'recipient-1',
          network: OrderBitcoinNetwork.bitcoin,
          paymentProcessor: SepaPaymentProcessor.confidential,
        ),
        throwsA(isA<ConfidentialSepaNotActivatedException>()),
      );
    });

    test('preserves the withdrawal datasource activation exception', () async {
      when(
        () => api.createWithdrawalOrder(
          apiKey: 'key',
          fiatAmount: 100,
          recipientId: 'recipient-1',
          paymentProcessor: SepaPaymentProcessor.confidential,
        ),
      ).thenThrow(const ConfidentialSepaNotActivatedApiException());

      expect(
        repository.placeWithdrawalOrder(
          fiatAmount: 100,
          recipientId: 'recipient-1',
          paymentProcessor: SepaPaymentProcessor.confidential,
        ),
        throwsA(isA<ConfidentialSepaNotActivatedException>()),
      );
    });

    test('preserves an unauthenticated withdrawal error', () async {
      when(
        () => apiKeys.get(isTestnet: any(named: 'isTestnet')),
      ).thenAnswer((_) async => null);

      expect(
        repository.placeWithdrawalOrder(
          fiatAmount: 100,
          recipientId: 'recipient-1',
        ),
        throwsA(isA<ApiKeyException>()),
      );
    });
  });
}
