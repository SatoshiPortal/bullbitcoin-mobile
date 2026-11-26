import 'package:bull_exchange/src/limit_orders/domain/limit_orders_list.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// Cancels every active limit order through the write gate of the session
/// the list opened with; it is never sent for another account, and without
/// a session it is a session rejection. Only a done cancel or a session
/// rejection is an answer; anything else leaves it to the list read after
/// it.
class CancelAllLimitOrdersUsecase {
  final Exchange _exchange;

  const CancelAllLimitOrdersUsecase(this._exchange);

  Future<LimitCancelAllAnswer> execute(ExchangeSession? session) async {
    if (session == null) return const CancelAllSessionRejected();
    final gated = await _exchange.writeGate.run(
      session,
      FinancialWriteKind.limitOrderCancel,
      () async => _exchange.currentSession != session
          ? const Err<List<LimitOrder>, ExchangeFailure>(
              ExchangeOperationStaleFailure(),
            )
          : await _exchange.limitOrders.cancelAll(),
    );
    return switch (gated) {
      GateRefused(:final refusal) => CancelAllGateRefused(refusal),
      GateAdmitted(result: Ok()) => const CancelAllDone(),
      GateAdmitted(result: Err(failure: ExchangeSessionRejectedFailure())) =>
        const CancelAllSessionRejected(),
      // Refused, lost or never sent: the list read after it decides.
      GateAdmitted(result: Err()) => const CancelAllUnsure(),
    };
  }
}
