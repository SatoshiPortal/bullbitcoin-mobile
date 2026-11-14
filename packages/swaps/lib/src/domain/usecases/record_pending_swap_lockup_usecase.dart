import 'package:primitives/primitives.dart';
import 'package:swaps/src/domain/entities/swap.dart';
import 'package:swaps/src/domain/entities/swap_failure.dart';
import 'package:swaps/src/domain/swap_resolver.dart';

/// Stores our signed lockup on the swap before it is broadcast, so a
/// broadcast whose outcome is unknown can be settled without ever funding the
/// swap twice. The caller must not broadcast when this fails.
class RecordPendingSwapLockupUsecase {
  final SwapResolver _resolver;

  const RecordPendingSwapLockupUsecase(this._resolver);

  Future<Result<Swap, SwapsFailure>> execute({
    required String swapId,
    required String signedTx,
  }) => _resolver.recordPendingLockup(swapId: swapId, signedTx: signedTx);
}
