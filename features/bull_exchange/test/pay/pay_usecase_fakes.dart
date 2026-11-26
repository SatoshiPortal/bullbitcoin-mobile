import 'package:bull_exchange/src/pay/domain/pay_flow.dart';
import 'package:bull_exchange/src/pay/domain/usecases/create_pay_order_usecase.dart';
import 'package:bull_exchange/src/pay/domain/usecases/load_pay_context_usecase.dart';
import 'package:bull_exchange/src/pay/domain/usecases/refresh_pay_order_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';

final class FakeLoadPayContextUsecase implements LoadPayContextUsecase {
  final Future<ExchangeRead<PayContext>> Function(ExchangeSession session)
  answer;

  FakeLoadPayContextUsecase(this.answer);

  @override
  Future<ExchangeRead<PayContext>> execute(ExchangeSession session) =>
      answer(session);
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
  final Future<ExchangeRead<Order>> Function(
    ExchangeSession session,
    String orderId,
  )
  answer;

  FakeRefreshPayOrderUsecase(this.answer);

  @override
  Future<ExchangeRead<Order>> execute(
    ExchangeSession session,
    String orderId,
  ) => answer(session, orderId);
}
