import 'package:bull_exchange/src/orders/domain/usecases/find_created_order_usecase.dart';
import 'package:bull_exchange/src/orders/domain/usecases/get_market_rate_usecase.dart';
import 'package:bull_exchange/src/orders/domain/usecases/get_order_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

final class FakeGetMarketRateUsecase implements GetMarketRateUsecase {
  final Future<Result<double, ExchangeReadFailure>> Function(
    ExchangeSession session,
    Market market,
  )
  answer;

  FakeGetMarketRateUsecase(this.answer);

  @override
  Future<Result<double, ExchangeReadFailure>> execute(
    ExchangeSession session,
    Market market,
  ) => answer(session, market);
}

final class FakeGetOrderUsecase implements GetOrderUsecase {
  final Future<Result<Order, ExchangeReadFailure>> Function(
    ExchangeSession session,
    String orderId,
  )
  answer;

  FakeGetOrderUsecase(this.answer);

  @override
  Future<Result<Order, ExchangeReadFailure>> execute(
    ExchangeSession session,
    String orderId,
  ) => answer(session, orderId);
}

/// Answers any order type; a found order that is not the type the flow
/// asks for fails the test, as the real use case would never return it.
final class FakeFindCreatedOrderUsecase implements FindCreatedOrderUsecase {
  final Future<Result<Order, ExchangeReadFailure>> Function(
    ExchangeSession session,
    OrderCreateJournalRequest journal,
    DateTime sentAt,
  )
  answer;

  FakeFindCreatedOrderUsecase(this.answer);

  @override
  Future<Result<O, ExchangeReadFailure>> execute<O extends Order>(
    ExchangeSession session,
    OrderCreateJournalRequest journal,
    DateTime sentAt,
  ) async => switch (await answer(session, journal, sentAt)) {
    Ok(value: final O order) => Ok(order),
    Ok(:final value) => throw StateError(
      'fake found a ${value.runtimeType}, flow asked for $O',
    ),
    Err(failure: ExchangeMissingFailure()) => const Err(
      ExchangeMissingFailure(),
    ),
    Err(failure: ExchangeUnreachableFailure(:final reason, :final isNetwork)) =>
      Err(ExchangeUnreachableFailure(reason, isNetwork: isNetwork)),
    Err(failure: ExchangeSessionRejectedFailure(:final why)) => Err(
      ExchangeSessionRejectedFailure(why),
    ),
    Err(failure: ExchangeMalformedFailure(:final reason)) => Err(
      ExchangeMalformedFailure(reason),
    ),
  };
}
