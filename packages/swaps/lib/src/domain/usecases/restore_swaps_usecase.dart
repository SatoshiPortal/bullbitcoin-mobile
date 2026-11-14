import 'package:primitives/primitives.dart';
import 'package:swaps/src/domain/entities/restored_swap.dart';
import 'package:swaps/src/domain/entities/swap.dart';
import 'package:swaps/src/domain/entities/swap_failure.dart';
import 'package:swaps/src/domain/swap_resolver.dart';
import 'package:swaps/src/domain/swap_store.dart';
import 'package:swaps/src/log.dart';

/// The swaps the provider can restore from our rescue key, each marked
/// against what is stored here.
class RestoreSwapsUsecase {
  final SwapResolver _resolver;
  final SwapStore _store;

  const RestoreSwapsUsecase(this._resolver, this._store);

  Future<Result<List<RestorableSwap>, SwapsFailure>> execute() async {
    final List<RestoredSwap> restored;
    switch (await _resolver.restore()) {
      case Ok(:final value):
        restored = value;
      case Err(:final failure):
        return Err(failure);
    }
    final Map<String, Swap> localSwaps;
    switch (await _store.all()) {
      case Ok(:final value):
        localSwaps = {for (final swap in value) swap.id: swap};
      case Err(:final failure):
        return Err(failure);
    }
    final result = [
      for (final swap in restored)
        RestorableSwap(
          swap: swap,
          existsLocally: localSwaps.containsKey(swap.id),
          locallyUnresolved: switch (localSwaps[swap.id]) {
            null => false,
            final stored => !stored.isLocallySettled(
              onChainRecoverable: swap.recoverable,
            ),
          },
        ),
    ];
    for (final r in result) {
      swapsLog.fine(
        'SWAPS: restore ${r.swap.id} ${r.swap.kind.name} '
        'recoverable=${r.swap.recoverable} local=${r.existsLocally} '
        '=> rescuable=${r.isRescuable}',
      );
    }
    await swapsLog.flush();
    return Ok(result);
  }
}
