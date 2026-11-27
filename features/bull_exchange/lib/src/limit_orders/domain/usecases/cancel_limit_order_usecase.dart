import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// Cancels one limit order through the write gate of [ExchangeSession]; it
/// is never sent once the user signed into another account. A failure is a
/// write failure ([writeOfResult]): the machine leaves anything but a session
/// rejection or a gate refusal to the re-read.
class CancelLimitOrderUsecase {
  final Exchange _exchange;

  const CancelLimitOrderUsecase(this._exchange);

  Future<Result<LimitOrder, ExchangeGatedWriteFailure>> execute(
    ExchangeSession session,
    String orderId,
  ) => _exchange.writeGate.run<Result<LimitOrder, ExchangeGatedWriteFailure>>(
    session,
    FinancialWriteKind.limitOrderCancel,
    () async =>
        writeOfResult(await _exchange.limitOrders.cancel(session, orderId)),
    refused: refusedWrite,
  );
}
