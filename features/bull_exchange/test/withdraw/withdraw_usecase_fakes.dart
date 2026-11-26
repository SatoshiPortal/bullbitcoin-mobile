import 'package:bull_exchange/src/withdraw/domain/usecases/confirm_withdraw_order_usecase.dart';
import 'package:bull_exchange/src/withdraw/domain/usecases/create_withdraw_order_usecase.dart';
import 'package:bull_exchange/src/withdraw/domain/usecases/load_withdraw_context_usecase.dart';
import 'package:bull_exchange/src/withdraw/domain/withdraw_flow.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';

final class FakeLoadWithdrawContextUsecase
    implements LoadWithdrawContextUsecase {
  final Future<ExchangeRead<WithdrawContext>> Function(ExchangeSession session)
  answer;

  FakeLoadWithdrawContextUsecase(this.answer);

  @override
  Future<ExchangeRead<WithdrawContext>> execute(ExchangeSession session) =>
      answer(session);
}

final class FakeCreateWithdrawOrderUsecase
    implements CreateWithdrawOrderUsecase {
  final Future<OrderCreateAnswered<WithdrawRequest, WithdrawOrder>> Function(
    ExchangeSession session,
    OrderSendCreate<WithdrawRequest> effect,
  )
  answer;

  FakeCreateWithdrawOrderUsecase(this.answer);

  @override
  Future<OrderCreateAnswered<WithdrawRequest, WithdrawOrder>> execute(
    ExchangeSession session,
    OrderSendCreate<WithdrawRequest> effect,
  ) => answer(session, effect);
}

final class FakeConfirmWithdrawOrderUsecase
    implements ConfirmWithdrawOrderUsecase {
  final Future<ConfirmAnswered<WithdrawConfirmTarget, WithdrawOrder>> Function(
    ExchangeSession session,
    ConfirmSend<WithdrawConfirmTarget> effect,
  )
  answer;

  FakeConfirmWithdrawOrderUsecase(this.answer);

  @override
  Future<ConfirmAnswered<WithdrawConfirmTarget, WithdrawOrder>> execute(
    ExchangeSession session,
    ConfirmSend<WithdrawConfirmTarget> effect,
  ) => answer(session, effect);
}
