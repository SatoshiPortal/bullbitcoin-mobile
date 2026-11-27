import 'package:bull_exchange/src/limit_orders/domain/limit_order_cancel_state.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// Cancels one limit order through the write gate of [ExchangeSession]; it
/// is never sent once the user signed into another account. Only a
/// cancelled order or a session rejection is an answer; anything else
/// leaves it to the re-read.
class CancelLimitOrderUsecase {
  final Exchange _exchange;

  const CancelLimitOrderUsecase(this._exchange);

  Future<LimitCancelAnswer> execute(
    ExchangeSession session,
    String orderId,
  ) async {
    final gated = await _exchange.writeGate.run(
      session,
      FinancialWriteKind.limitOrderCancel,
      () => _exchange.limitOrders.cancel(session, orderId),
    );
    return switch (gated) {
      GateRefused(:final refusal) => CancelAnsweredGateRefused(refusal),
      GateAdmitted(result: Ok(:final value)) => CancelAnsweredOrder(value),
      GateAdmitted(result: Err(failure: ExchangeSessionRejectedFailure())) =>
        const CancelAnsweredSessionRejected(),
      // Refused, lost or never sent: the re-read decides.
      GateAdmitted(result: Err()) => const CancelAnsweredUnsure(),
    };
  }
}
