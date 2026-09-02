import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/features/sell/domain/label_completed_sell_order_usecase.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bb_mobile/features/transactions/transactions_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockTransactionsFacade extends Mock implements TransactionsFacade {}

class _MockOrder extends Mock implements SellOrder {}

void main() {
  late _MockTransactionsFacade facade;
  late LabelCompletedSellOrderUsecase usecase;

  setUp(() {
    facade = _MockTransactionsFacade();
    usecase = LabelCompletedSellOrderUsecase(transactionsFacade: facade);
  });

  _MockOrder orderWith(OrderStatus status) {
    final order = _MockOrder();
    when(() => order.orderStatus).thenReturn(status);
    return order;
  }

  test('labels a completed order', () async {
    final order = orderWith(OrderStatus.completed);
    when(
      () => facade.labelCompletedExchangeOrders(any()),
    ).thenAnswer((_) async {});

    final result = await usecase.execute(order: order);

    expect(result, isA<Ok<void, SellFailure>>());
    verify(() => facade.labelCompletedExchangeOrders([order])).called(1);
  });

  // #2624: privileged exchange labels must never be written from anything but
  // an explicit completion.
  test('writes nothing for an order that has not completed', () async {
    for (final status in [
      OrderStatus.inProgress,
      OrderStatus.awaitingConfirmation,
      OrderStatus.expired,
      OrderStatus.failed,
    ]) {
      final result = await usecase.execute(order: orderWith(status));

      expect(result, isA<Ok<void, SellFailure>>());
    }

    verifyNever(() => facade.labelCompletedExchangeOrders(any()));
  });

  test('a labelling failure is reported, not thrown', () async {
    final order = orderWith(OrderStatus.completed);
    when(
      () => facade.labelCompletedExchangeOrders(any()),
    ).thenThrow(Exception('label store unavailable'));

    final result = await usecase.execute(order: order);

    switch (result) {
      case Ok():
        fail('a labelling failure must be visible to the caller');
      case Err(:final failure):
        // Cosmetic: the caller drops this so a completed sale still shows as
        // completed. It must not escape as an exception and break that.
        expect(failure, isA<SellUnexpectedFailure>());
    }
  });
}
