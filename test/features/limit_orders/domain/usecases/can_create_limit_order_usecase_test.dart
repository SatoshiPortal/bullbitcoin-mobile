import 'package:bb_mobile/features/limit_orders/domain/usecases/can_create_limit_order_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../limit_order_fixtures.dart';

void main() {
  const usecase = CanCreateLimitOrderUsecase();

  test('allows creation below the active-order maximum', () {
    final orders = List.generate(
      CanCreateLimitOrderUsecase.maximumActiveOrders - 1,
      (index) => limitOrder(id: 'lo-$index'),
    );

    expect(usecase.execute(orders), isTrue);
  });

  test('rejects creation at the active-order maximum', () {
    final orders = List.generate(
      CanCreateLimitOrderUsecase.maximumActiveOrders,
      (index) => limitOrder(id: 'lo-$index'),
    );

    expect(usecase.execute(orders), isFalse);
  });
}
