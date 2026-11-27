import 'package:bull_exchange/src/pay/domain/pay_state.dart';
import 'package:bull_exchange/src/pay/domain/usecases/create_pay_order_usecase.dart';
import 'package:bull_exchange/src/pay/domain/usecases/load_pay_context_usecase.dart';
import 'package:bull_exchange/src/pay/domain/usecases/refresh_pay_order_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:primitives/primitives.dart';

final class FakeLoadPayContextUsecase implements LoadPayContextUsecase {
  final Future<Result<PayContext, ExchangeReadFailure>> Function(
    ExchangeSession session,
  )
  answer;

  FakeLoadPayContextUsecase(this.answer);

  @override
  Future<Result<PayContext, ExchangeReadFailure>> execute(
    ExchangeSession session,
  ) => answer(session);
}

final class FakeCreatePayOrderUsecase implements CreatePayOrderUsecase {
  final Future<OrderCreateAnswered<PayRequest, Order>> Function(
    ExchangeSession session,
    OrderSendCreate<PayRequest> effect,
  )
  answer;

  FakeCreatePayOrderUsecase(this.answer);

  @override
  Future<OrderCreateAnswered<PayRequest, Order>> execute(
    ExchangeSession session,
    OrderSendCreate<PayRequest> effect,
  ) => answer(session, effect);
}

final class FakeRefreshPayOrderUsecase implements RefreshPayOrderUsecase {
  final Future<Result<Order, ExchangeReadFailure>> Function(
    ExchangeSession session,
    String orderId,
  )
  answer;

  FakeRefreshPayOrderUsecase(this.answer);

  @override
  Future<Result<Order, ExchangeReadFailure>> execute(
    ExchangeSession session,
    String orderId,
  ) => answer(session, orderId);
}
