import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_order_usercase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transaction_order_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetOrderUsecase extends Mock implements GetOrderUsecase {}

Order _order() => Order.buy(
  orderId: 'order-1',
  orderType: OrderType.buy,
  message: OrderMessage(code: '', message: ''),
  orderNumber: 1,
  payinAmount: 100,
  payinCurrency: 'CAD',
  payoutAmount: 0.001,
  payoutCurrency: 'BTC',
  payinMethod: OrderPaymentMethod.eTransfer,
  payoutMethod: OrderPaymentMethod.bitcoin,
  orderStatus: OrderStatus.inProgress,
  payinStatus: OrderPayinStatus.completed,
  payoutStatus: OrderPayoutStatus.completed,
  createdAt: DateTime.utc(2026, 8, 19),
  isTestnet: false,
);

void main() {
  late _MockGetOrderUsecase getOrder;
  late GetTransactionOrderUsecase usecase;

  setUp(() {
    getOrder = _MockGetOrderUsecase();
    usecase = GetTransactionOrderUsecase(getOrder);
  });

  test('forwards the order on success', () async {
    final order = _order();
    when(
      () => getOrder.execute(orderId: 'order-1'),
    ).thenAnswer((_) async => order);

    expect((await usecase.execute('order-1') as Ok).value, order);
  });

  test('sanitizes an exchange API error', () async {
    when(() => getOrder.execute(orderId: 'order-1')).thenThrow(
      GetOrderException('401 {"error":"invalid api key bb_live_abc123"}'),
    );

    final result = await usecase.execute('order-1');

    final failure = (result as Err).failure as TransactionFailure;
    expect(failure, isA<TransactionUnexpectedFailure>());
    // An API key in an error body is the worst case of a raw leak (#2140).
    expect(failure.logMessage, isNot(contains('bb_live')));
    expect(failure.logMessage, isNot(contains('api key')));
  });
}
