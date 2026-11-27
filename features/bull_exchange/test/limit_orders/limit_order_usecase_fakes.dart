import 'package:bull_exchange/src/limit_orders/domain/limit_order_cancel.dart';
import 'package:bull_exchange/src/limit_orders/domain/limit_order_flow.dart';
import 'package:bull_exchange/src/limit_orders/domain/limit_orders_list.dart';
import 'package:bull_exchange/src/limit_orders/domain/usecases/cancel_all_limit_orders_usecase.dart';
import 'package:bull_exchange/src/limit_orders/domain/usecases/cancel_limit_order_usecase.dart';
import 'package:bull_exchange/src/limit_orders/domain/usecases/create_limit_order_usecase.dart';
import 'package:bull_exchange/src/limit_orders/domain/usecases/get_active_limit_orders_usecase.dart';
import 'package:bull_exchange/src/limit_orders/domain/usecases/get_limit_order_rate_usecase.dart';
import 'package:bull_exchange/src/limit_orders/domain/usecases/get_limit_order_usecase.dart';
import 'package:bull_exchange/src/limit_orders/domain/usecases/get_limit_receive_address_usecase.dart';
import 'package:bull_exchange/src/limit_orders/domain/usecases/get_recent_limit_orders_usecase.dart';
import 'package:bull_exchange/src/limit_orders/domain/usecases/load_limit_order_context_usecase.dart';
import 'package:bull_exchange/src/limit_orders/domain/usecases/validate_lightning_address_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:primitives/primitives.dart';

final class FakeLoadLimitOrderContextUsecase
    implements LoadLimitOrderContextUsecase {
  final Future<Result<LimitOrderContext, ExchangeReadFailure>> Function(
    ExchangeSession session,
  )
  answer;

  FakeLoadLimitOrderContextUsecase(this.answer);

  @override
  Future<Result<LimitOrderContext, ExchangeReadFailure>> execute(
    ExchangeSession session,
  ) => answer(session);
}

final class FakeGetLimitOrderRateUsecase implements GetLimitOrderRateUsecase {
  final Future<Result<LimitOrderRate, ExchangeReadFailure>> Function(
    ExchangeSession session,
    Market market,
  )
  answer;

  FakeGetLimitOrderRateUsecase(this.answer);

  @override
  Future<Result<LimitOrderRate, ExchangeReadFailure>> execute(
    ExchangeSession session,
    Market market,
  ) => answer(session, market);
}

final class FakeGetLimitReceiveAddressUsecase
    implements GetLimitReceiveAddressUsecase {
  final Future<Result<Destination, Failure>> Function(
    DestinationOptionAppWallet option,
  )
  answer;

  FakeGetLimitReceiveAddressUsecase(this.answer);

  @override
  Future<Result<Destination, Failure>> execute(
    DestinationOptionAppWallet option,
  ) => answer(option);
}

final class FakeValidateLightningAddressUsecase
    implements ValidateLightningAddressUsecase {
  final Future<Result<Destination, Failure>> Function(String text) answer;

  FakeValidateLightningAddressUsecase(this.answer);

  @override
  Future<Result<Destination, Failure>> execute(String text) => answer(text);
}

final class FakeCreateLimitOrderUsecase implements CreateLimitOrderUsecase {
  final Future<ConfirmAnswered<LimitOrderRequest, LimitOrder>> Function(
    ExchangeSession session,
    ConfirmSend<LimitOrderRequest> effect,
  )
  answer;

  FakeCreateLimitOrderUsecase(this.answer);

  @override
  Future<ConfirmAnswered<LimitOrderRequest, LimitOrder>> execute(
    ExchangeSession session,
    ConfirmSend<LimitOrderRequest> effect,
  ) => answer(session, effect);
}

final class FakeGetRecentLimitOrdersUsecase
    implements GetRecentLimitOrdersUsecase {
  final Future<Result<List<LimitOrder>, ExchangeReadFailure>> Function(
    ExchangeSession session,
  )
  answer;

  FakeGetRecentLimitOrdersUsecase(this.answer);

  @override
  Future<Result<List<LimitOrder>, ExchangeReadFailure>> execute(
    ExchangeSession session,
  ) => answer(session);
}

final class FakeGetLimitOrderUsecase implements GetLimitOrderUsecase {
  final Future<Result<LimitOrder, ExchangeReadFailure>> Function(
    ExchangeSession session,
    String orderId,
  )
  answer;

  FakeGetLimitOrderUsecase(this.answer);

  @override
  Future<Result<LimitOrder, ExchangeReadFailure>> execute(
    ExchangeSession session,
    String orderId,
  ) => answer(session, orderId);
}

final class FakeCancelLimitOrderUsecase implements CancelLimitOrderUsecase {
  final Future<LimitCancelAnswer> Function(
    ExchangeSession session,
    String orderId,
  )
  answer;

  FakeCancelLimitOrderUsecase(this.answer);

  @override
  Future<LimitCancelAnswer> execute(ExchangeSession session, String orderId) =>
      answer(session, orderId);
}

final class FakeGetActiveLimitOrdersUsecase
    implements GetActiveLimitOrdersUsecase {
  final Future<Result<List<LimitOrder>, ExchangeReadFailure>> Function(
    ExchangeSession? session,
  )
  answer;

  FakeGetActiveLimitOrdersUsecase(this.answer);

  @override
  Future<Result<List<LimitOrder>, ExchangeReadFailure>> execute(
    ExchangeSession? session,
  ) => answer(session);
}

final class FakeCancelAllLimitOrdersUsecase
    implements CancelAllLimitOrdersUsecase {
  final Future<LimitCancelAllAnswer> Function(ExchangeSession? session) answer;

  FakeCancelAllLimitOrdersUsecase(this.answer);

  @override
  Future<LimitCancelAllAnswer> execute(ExchangeSession? session) =>
      answer(session);
}
