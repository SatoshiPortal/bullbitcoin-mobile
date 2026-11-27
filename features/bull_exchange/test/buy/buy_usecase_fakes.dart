import 'package:bull_exchange/src/buy/domain/buy_accelerate_state.dart';
import 'package:bull_exchange/src/buy/domain/buy_state.dart';
import 'package:bull_exchange/src/buy/domain/usecases/accelerate_buy_order_usecase.dart';
import 'package:bull_exchange/src/buy/domain/usecases/confirm_buy_order_usecase.dart';
import 'package:bull_exchange/src/buy/domain/usecases/create_buy_order_usecase.dart';
import 'package:bull_exchange/src/buy/domain/usecases/find_created_buy_order_usecase.dart';
import 'package:bull_exchange/src/buy/domain/usecases/get_buy_order_usecase.dart';
import 'package:bull_exchange/src/buy/domain/usecases/get_buy_receive_address_usecase.dart';
import 'package:bull_exchange/src/buy/domain/usecases/load_accelerate_quote_usecase.dart';
import 'package:bull_exchange/src/buy/domain/usecases/load_buy_context_usecase.dart';
import 'package:bull_exchange/src/buy/domain/usecases/refresh_buy_order_usecase.dart';
import 'package:bull_exchange/src/buy/domain/usecases/release_buy_payjoin_usecase.dart';
import 'package:bull_exchange/src/buy/domain/usecases/settle_buy_payout_usecase.dart';
import 'package:bull_exchange/src/buy/domain/usecases/validate_buy_address_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:primitives/primitives.dart';

final class FakeLoadBuyContextUsecase implements LoadBuyContextUsecase {
  final Future<Result<BuyContext, ExchangeReadFailure>> Function(
    ExchangeSession session,
  )
  answer;

  FakeLoadBuyContextUsecase(this.answer);

  @override
  Future<Result<BuyContext, ExchangeReadFailure>> execute(
    ExchangeSession session,
  ) => answer(session);
}

final class FakeGetBuyReceiveAddressUsecase
    implements GetBuyReceiveAddressUsecase {
  final Future<Result<Destination, ExchangeFailure>> Function(
    DestinationOptionAppWallet option,
  )
  answer;

  FakeGetBuyReceiveAddressUsecase(this.answer);

  @override
  Future<Result<Destination, ExchangeFailure>> execute(
    DestinationOptionAppWallet option,
  ) => answer(option);
}

final class FakeValidateBuyAddressUsecase implements ValidateBuyAddressUsecase {
  final Future<Result<Destination, ExchangeFailure>> Function(String text)
  answer;

  FakeValidateBuyAddressUsecase(this.answer);

  @override
  Future<Result<Destination, ExchangeFailure>> execute(String text) =>
      answer(text);
}

final class FakeCreateBuyOrderUsecase implements CreateBuyOrderUsecase {
  final Future<OrderCreateAnswered<BuyRequest, BuyOrder>> Function(
    ExchangeSession session,
    OrderSendCreate<BuyRequest> effect,
  )
  answer;

  FakeCreateBuyOrderUsecase(this.answer);

  @override
  Future<OrderCreateAnswered<BuyRequest, BuyOrder>> execute(
    ExchangeSession session,
    OrderSendCreate<BuyRequest> effect,
  ) => answer(session, effect);
}

final class FakeFindCreatedBuyOrderUsecase
    implements FindCreatedBuyOrderUsecase {
  final Future<Result<BuyOrder, ExchangeReadFailure>> Function(
    ExchangeSession session,
    BuyRequest request,
    DateTime sentAt,
  )
  answer;

  FakeFindCreatedBuyOrderUsecase(this.answer);

  @override
  Future<Result<BuyOrder, ExchangeReadFailure>> execute(
    ExchangeSession session,
    BuyRequest request,
    DateTime sentAt,
  ) => answer(session, request, sentAt);
}

final class FakeRefreshBuyOrderUsecase implements RefreshBuyOrderUsecase {
  final Future<Result<BuyOrder, ExchangeReadFailure>> Function(
    ExchangeSession session,
    String orderId,
  )
  answer;

  FakeRefreshBuyOrderUsecase(this.answer);

  @override
  Future<Result<BuyOrder, ExchangeReadFailure>> execute(
    ExchangeSession session,
    String orderId,
  ) => answer(session, orderId);
}

final class FakeConfirmBuyOrderUsecase implements ConfirmBuyOrderUsecase {
  final Future<ConfirmAnswered<BuyConfirmTarget, BuyOrder>> Function(
    ExchangeSession session,
    ConfirmSend<BuyConfirmTarget> effect,
  )
  answer;

  FakeConfirmBuyOrderUsecase(this.answer);

  @override
  Future<ConfirmAnswered<BuyConfirmTarget, BuyOrder>> execute(
    ExchangeSession session,
    ConfirmSend<BuyConfirmTarget> effect,
  ) => answer(session, effect);
}

final class FakeGetBuyOrderUsecase implements GetBuyOrderUsecase {
  final Future<Result<BuyOrder, ExchangeReadFailure>> Function(
    ExchangeSession session,
    String orderId,
  )
  answer;

  FakeGetBuyOrderUsecase(this.answer);

  @override
  Future<Result<BuyOrder, ExchangeReadFailure>> execute(
    ExchangeSession session,
    String orderId,
  ) => answer(session, orderId);
}

final class FakeReleaseBuyPayjoinUsecase implements ReleaseBuyPayjoinUsecase {
  final Future<void> Function(BuyOrder order) answer;

  FakeReleaseBuyPayjoinUsecase(this.answer);

  @override
  Future<void> execute(BuyOrder order) => answer(order);
}

final class FakeSettleBuyPayoutUsecase implements SettleBuyPayoutUsecase {
  final Future<void> Function(BuyOrder order, String? walletId) answer;

  FakeSettleBuyPayoutUsecase(this.answer);

  @override
  Future<void> execute(BuyOrder order, String? walletId) =>
      answer(order, walletId);
}

final class FakeLoadAccelerateQuoteUsecase
    implements LoadAccelerateQuoteUsecase {
  final Future<Result<AccelerateQuote, ExchangeReadFailure>> Function(
    ExchangeSession session,
    String orderId,
  )
  answer;

  FakeLoadAccelerateQuoteUsecase(this.answer);

  @override
  Future<Result<AccelerateQuote, ExchangeReadFailure>> execute(
    ExchangeSession session,
    String orderId,
  ) => answer(session, orderId);
}

final class FakeAccelerateBuyOrderUsecase implements AccelerateBuyOrderUsecase {
  final Future<ConfirmAnswered<AccelerateTarget, BuyOrder>> Function(
    ExchangeSession session,
    ConfirmSend<AccelerateTarget> effect,
  )
  answer;

  FakeAccelerateBuyOrderUsecase(this.answer);

  @override
  Future<ConfirmAnswered<AccelerateTarget, BuyOrder>> execute(
    ExchangeSession session,
    ConfirmSend<AccelerateTarget> effect,
  ) => answer(session, effect);
}
