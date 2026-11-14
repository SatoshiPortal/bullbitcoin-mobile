import 'package:primitives/primitives.dart';
import 'package:swaps/src/domain/entities/swap_failure.dart';
import 'package:swaps/src/domain/swap_resolver.dart';

/// Forgets a stored lockup that was never relayed: the node refused it, or
/// the spend gate stopped it before it was sent.
class DropPendingSwapLockupUsecase {
  final SwapResolver _resolver;

  const DropPendingSwapLockupUsecase(this._resolver);

  Future<Result<void, SwapsFailure>> execute(String swapId) =>
      _resolver.dropPendingLockup(swapId);
}
