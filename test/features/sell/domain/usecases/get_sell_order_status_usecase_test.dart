import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_order_usercase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bb_mobile/features/sell/domain/usecases/get_sell_order_status_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetOrderUsecase extends Mock implements GetOrderUsecase {}

class MockSellOrder extends Mock implements SellOrder {}

void main() {
  late MockGetOrderUsecase getOrder;
  late GetSellOrderStatusUsecase usecase;

  setUp(() {
    getOrder = MockGetOrderUsecase();
    usecase = GetSellOrderStatusUsecase(getOrderUsecase: getOrder);
  });

  group('GetSellOrderStatusUsecase', () {
    test('returns Ok(order) when a SellOrder comes back', () async {
      final sellOrder = MockSellOrder();
      when(
        () => getOrder.execute(orderId: any(named: 'orderId')),
      ).thenAnswer((_) async => sellOrder);

      final result = await usecase.execute(orderId: 'order-1');

      expect(result, isA<Ok<SellOrder, SellFailure>>());
      expect((result as Ok).value, sellOrder);
    });

    test(
      'maps a throw to SellUnexpectedFailure — raw in logMessage only, no leak',
      () async {
        when(
          () => getOrder.execute(orderId: any(named: 'orderId')),
        ).thenThrow(Exception('poll boom'));

        final result = await usecase.execute(orderId: 'order-1');

        expect(result, isA<Err>());
        final failure = (result as Err).failure;
        expect(failure, isA<SellUnexpectedFailure>());
        expect(
          (failure as SellUnexpectedFailure).logMessage,
          contains('poll boom'),
        );
      },
    );
  });
}
