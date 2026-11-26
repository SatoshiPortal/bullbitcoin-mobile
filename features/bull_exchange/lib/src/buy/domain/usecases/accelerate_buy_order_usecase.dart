import 'package:bull_exchange/src/buy/domain/buy_accelerate_flow.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';

/// Asks the exchange to pay the buy order out express, through the
/// account's write gate.
class AccelerateBuyOrderUsecase {
  final Exchange _exchange;

  const AccelerateBuyOrderUsecase(this._exchange);

  Future<ConfirmAnswered<AccelerateTarget, BuyOrder>> execute(
    ExchangeSession session,
    ConfirmSend<AccelerateTarget> effect,
  ) => runServerConfirm(
    gate: _exchange.writeGate,
    session: session,
    policy: accelerateConfirmPolicy,
    effect: effect,
    confirm: (target) => _exchange
        .orders(session.environment)
        .accelerateBuyOrder(target.orderId),
  );
}
