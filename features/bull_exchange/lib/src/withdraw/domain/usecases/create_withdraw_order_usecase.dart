import 'package:bull_exchange/src/withdraw/domain/withdraw_flow.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';

/// Places the withdrawal order through the account's write gate; an unknown
/// outcome is journaled so the next start reconciles it.
class CreateWithdrawOrderUsecase {
  final Exchange _exchange;

  const CreateWithdrawOrderUsecase(this._exchange);

  Future<OrderCreateAnswered<WithdrawRequest, WithdrawOrder>> execute(
    ExchangeSession session,
    OrderSendCreate<WithdrawRequest> effect,
  ) => runOrderCreate(
    gate: _exchange.writeGate,
    session: session,
    effect: effect,
    create: (request) {
      final payout = request.payout;
      return _exchange
          .orders(session.environment)
          .placeWithdrawalOrder(
            fiatAmount: request.amount.fiat,
            recipientId: payout.recipientId,
            paymentProcessor: payout.paymentProcessor,
            securityQuestion: payout.interacAnswer?.question,
            securityAnswer: payout.interacAnswer?.answer,
          );
    },
    journalUnknown: (request) =>
        _exchange.journalUnknownOrderCreate(session, request.journal),
  );
}
