import 'package:bull_exchange/src/limit_orders/domain/limit_order_flow.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';

/// Creates the reviewed limit order through the account's write gate. The
/// create goes to the account of the flow's session only: when the user
/// signed into another one since, it is not sent.
class CreateLimitOrderUsecase {
  final Exchange _exchange;

  const CreateLimitOrderUsecase(this._exchange);

  Future<ConfirmAnswered<LimitOrderRequest, LimitOrder>> execute(
    ExchangeSession session,
    ConfirmSend<LimitOrderRequest> effect,
  ) => runServerConfirm(
    gate: _exchange.writeGate,
    session: session,
    policy: limitOrderCreatePolicy,
    effect: effect,
    confirm: (request) async => _exchange.currentSession != session
        ? const WriteNotSent(ExchangeNotSentReason.sessionChanged)
        : await _exchange.limitOrders.create(request.draft),
  );
}
