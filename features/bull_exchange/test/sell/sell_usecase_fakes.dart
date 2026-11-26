import 'package:bull_exchange/src/sell/domain/sell_flow.dart';
import 'package:bull_exchange/src/sell/domain/usecases/create_sell_order_usecase.dart';
import 'package:bull_exchange/src/sell/domain/usecases/load_sell_context_usecase.dart';
import 'package:bull_exchange/src/sell/domain/usecases/refresh_sell_order_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';

final class FakeLoadSellContextUsecase implements LoadSellContextUsecase {
  final Future<ExchangeRead<SellContext>> Function(ExchangeSession session)
  answer;

  FakeLoadSellContextUsecase(this.answer);

  @override
  Future<ExchangeRead<SellContext>> execute(ExchangeSession session) =>
      answer(session);
}

final class FakeCreateSellOrderUsecase implements CreateSellOrderUsecase {
  final Future<OrderCreateAnswered<SellRequest, Order>> Function(
    ExchangeSession session,
    OrderSendCreate<SellRequest> effect,
  )
  answer;

  FakeCreateSellOrderUsecase(this.answer);

  @override
  Future<OrderCreateAnswered<SellRequest, Order>> execute(
    ExchangeSession session,
    OrderSendCreate<SellRequest> effect,
  ) => answer(session, effect);
}

final class FakeRefreshSellOrderUsecase implements RefreshSellOrderUsecase {
  final Future<ExchangeRead<Order>> Function(
    ExchangeSession session,
    Order order,
  )
  answer;

  FakeRefreshSellOrderUsecase(this.answer);

  @override
  Future<ExchangeRead<Order>> execute(ExchangeSession session, Order order) =>
      answer(session, order);
}
