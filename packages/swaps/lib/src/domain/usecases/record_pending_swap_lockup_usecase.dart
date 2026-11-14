import 'package:primitives/primitives.dart';
import 'package:swaps/src/domain/entities/swap.dart';
import 'package:swaps/src/domain/entities/swap_failure.dart';
import 'package:swaps/src/domain/swap_repository.dart';
import 'package:swaps/src/log.dart';

/// Stores our signed lockup on the swap before it is broadcast, so a
/// broadcast whose outcome is unknown can be settled without ever funding the
/// swap twice. The caller must not broadcast when this fails.
class RecordPendingSwapLockupUsecase {
  final SwapRepository _swapRepository;

  const RecordPendingSwapLockupUsecase(this._swapRepository);

  Future<Result<Swap, SwapsFailure>> execute({
    required String swapId,
    required String signedTx,
  }) async {
    try {
      return Ok(
        await _swapRepository.recordPendingLockup(
          swapId: swapId,
          signedTx: signedTx,
        ),
      );
    } catch (e) {
      swapsLog.warning(
        'SWAPS: lockup of $swapId not stored before broadcast '
        '(${e.runtimeType})',
      );
      return Err(classifySwapsFailure(e));
    }
  }
}
