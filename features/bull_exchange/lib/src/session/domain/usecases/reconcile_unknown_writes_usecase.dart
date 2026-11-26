import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// Settles writes whose outcome was unknown by re-reading them; never sends
/// them again. Acts on the journal of the exchange's CURRENT session point.
class ReconcileUnknownWritesUsecase {
  final Exchange _exchange;

  const ReconcileUnknownWritesUsecase(this._exchange);

  Future<Result<UnknownWriteReconciliation, Failure>> execute() =>
      _exchange.reconcileUnknownWrites();
}
