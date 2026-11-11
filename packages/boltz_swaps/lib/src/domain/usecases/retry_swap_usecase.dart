import 'package:boltz_swaps/src/domain/entities/swap.dart';
import 'package:boltz_swaps/src/domain/entities/swap_failure.dart';
import 'package:boltz_swaps/src/domain/swap_repository.dart';
import 'package:boltz_swaps/src/log.dart';
import 'package:primitives/primitives.dart';

/// User-triggered "retry now" for a swap whose claim or refund has not landed.
///
/// Drives the resolve on the **script path only** (no cooperative close) and
/// through the user's own electrum, so it makes **no call to the Boltz API**
/// (api.boltz.exchange): no cooperative signature request, no Boltz fee quote,
/// no Boltz broadcast, no outspend lookup. It does not go through the
/// background `SwapWatcher` — the resolve is driven directly here — so it works
/// even when the watcher cannot reach Boltz.
///
/// Returns the refreshed swap so the caller can reflect the new status.
class RetrySwapUsecase {
  RetrySwapUsecase({required this._swapRepository});

  final SwapRepository _swapRepository;

  Future<Result<Swap, SwapsFailure>> execute({required Swap swap}) async {
    try {
      await _swapRepository.resolveScriptPath(swap);
      return Ok(await _swapRepository.get(swap.id));
    } catch (e) {
      swapsLog.warning('SWAPS: retry failed for ${swap.id}: $e');
      return Err(classifySwapsFailure(e));
    }
  }
}
