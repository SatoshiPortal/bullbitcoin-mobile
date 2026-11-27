import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// Cancels every active limit order through the write gate of the session
/// the list opened with; it is never sent for another account, and without
/// a session it is a session rejection.
class CancelAllLimitOrdersUsecase {
  final Exchange _exchange;

  const CancelAllLimitOrdersUsecase(this._exchange);

  Future<Result<void, ExchangeGatedWriteFailure>> execute(
    ExchangeSession? session,
  ) async => switch (session) {
    null => const Err(
      ExchangeSessionRejectedFailure(ExchangeSessionRejection.signedOut),
    ),
    final ExchangeSession session =>
      await _exchange.writeGate.run<Result<void, ExchangeGatedWriteFailure>>(
        session,
        FinancialWriteKind.limitOrderCancel,
        () async => writeOfResult(
          (await _exchange.limitOrders.cancelAll(session)).map((_) {}),
        ),
        refused: refusedWrite,
      ),
  };
}
