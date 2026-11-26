import 'package:bull_exchange/src/orders/domain/usecases/find_created_order_usecase.dart';
import 'package:bull_exchange/src/orders/domain/usecases/get_market_rate_usecase.dart';
import 'package:bull_exchange/src/orders/domain/usecases/get_order_usecase.dart';
import 'package:exchange/exchange.dart';

final class FakeGetMarketRateUsecase implements GetMarketRateUsecase {
  final Future<ExchangeRead<double>> Function(Market market) answer;

  FakeGetMarketRateUsecase(this.answer);

  @override
  Future<ExchangeRead<double>> execute(Market market) => answer(market);
}

final class FakeGetOrderUsecase implements GetOrderUsecase {
  final Future<ExchangeRead<Order>> Function(
    ExchangeSession session,
    String orderId,
  )
  answer;

  FakeGetOrderUsecase(this.answer);

  @override
  Future<ExchangeRead<Order>> execute(
    ExchangeSession session,
    String orderId,
  ) => answer(session, orderId);
}

/// Answers any order type; a found order that is not the type the flow
/// asks for fails the test, as the real use case would never return it.
final class FakeFindCreatedOrderUsecase implements FindCreatedOrderUsecase {
  final Future<ExchangeRead<Order>> Function(
    ExchangeSession session,
    OrderCreateJournalRequest journal,
    DateTime sentAt,
  )
  answer;

  FakeFindCreatedOrderUsecase(this.answer);

  @override
  Future<ExchangeRead<O>> execute<O extends Order>(
    ExchangeSession session,
    OrderCreateJournalRequest journal,
    DateTime sentAt,
  ) async => switch (await answer(session, journal, sentAt)) {
    ReadGot(value: final O order) => ReadGot(order),
    ReadGot(:final value) => throw StateError(
      'fake found a ${value.runtimeType}, flow asked for $O',
    ),
    ReadMissing() => const ReadMissing(),
    ReadUnreachable(:final reason, :final isNetwork) => ReadUnreachable(
      reason,
      isNetwork: isNetwork,
    ),
    ReadSessionRejected(:final why) => ReadSessionRejected(why),
    ReadMalformed(:final reason) => ReadMalformed(reason),
  };
}
