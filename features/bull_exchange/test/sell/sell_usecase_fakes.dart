import 'package:bull_exchange/src/sell/domain/sell_state.dart';
import 'package:bull_exchange/src/sell/domain/usecases/create_sell_order_usecase.dart';
import 'package:bull_exchange/src/sell/domain/usecases/load_sell_context_usecase.dart';
import 'package:bull_exchange/src/sell/domain/usecases/refresh_sell_order_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:primitives/primitives.dart';

final class FakeLoadSellContextUsecase implements LoadSellContextUsecase {
  final Future<Result<SellContext, ExchangeReadFailure>> Function(
    ExchangeSession session,
  )
  answer;

  FakeLoadSellContextUsecase(this.answer);

  @override
  Future<Result<SellContext, ExchangeReadFailure>> execute(
    ExchangeSession session,
  ) => answer(session);
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
  final Future<Result<Order, ExchangeReadFailure>> Function(
    ExchangeSession session,
    Order order,
  )
  answer;

  FakeRefreshSellOrderUsecase(this.answer);

  @override
  Future<Result<Order, ExchangeReadFailure>> execute(
    ExchangeSession session,
    Order order,
  ) => answer(session, order);
}
