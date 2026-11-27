import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// Settles writes whose outcome was unknown by re-reading them; never sends
/// them again. Acts on the journal of [ExchangeSession]'s environment, only
/// while it is the current session.
class ReconcileUnknownWritesUsecase {
  final Exchange _exchange;

  const ReconcileUnknownWritesUsecase(this._exchange);

  Future<Result<UnknownWriteReconciliation, ExchangeFailure>> execute(
    ExchangeSession session,
  ) => _exchange.reconcileUnknownWrites(session);
}
