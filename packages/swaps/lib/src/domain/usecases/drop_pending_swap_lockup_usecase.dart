import 'package:primitives/primitives.dart';
import 'package:swaps/src/domain/entities/swap_failure.dart';
import 'package:swaps/src/domain/swap_repository.dart';

/// Forgets a stored lockup that was never relayed: the node refused it, or
/// the spend gate stopped it before it was sent.
class DropPendingSwapLockupUsecase {
  final SwapRepository _swapRepository;

  const DropPendingSwapLockupUsecase(this._swapRepository);

  Future<Result<void, SwapsFailure>> execute(String swapId) async {
    try {
      await _swapRepository.dropPendingLockup(swapId);
      return const Ok(null);
    } catch (e) {
      return Err(classifySwapsFailure(e));
    }
  }
}
