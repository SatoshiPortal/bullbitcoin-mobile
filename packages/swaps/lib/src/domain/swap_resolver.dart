import 'package:primitives/primitives.dart';
import 'package:swaps/src/domain/entities/restored_swap.dart';
import 'package:swaps/src/domain/entities/swap.dart';
import 'package:swaps/src/domain/entities/swap_failure.dart';

/// Drives one provider's swaps to resolution. Every provider implements
/// it; the [SwapWatcher] needs nothing else.
abstract interface class SwapResolver {
  bool get isTestnet;

  /// Swaps the provider changed, as it reports them.
  Stream<Swap> get updates;

  /// Settles a lockup whose broadcast is being confirmed, then performs
  /// [Swap.nextAction]: claim, refund or the cooperative signature. Returns
  /// the swap as stored afterwards.
  Future<Result<Swap, SwapsFailure>> resolve(Swap swap);

  /// [resolve] on the script path only, without the provider: the way out
  /// when the provider is unreachable or will not cooperate.
  Future<Result<Swap, SwapsFailure>> resolveScriptPath(Swap swap);

  /// Subscribes [swapIds] to live provider events.
  void listen(List<String> swapIds);

  /// Pulls each swap's current provider status through the same pipeline
  /// as live events: recovery never depends on event replay.
  Future<Result<void, SwapsFailure>> reconcile(List<String> swapIds);

  /// Reopens swaps recorded as resolved without proof on chain.
  Future<Result<void, SwapsFailure>> verifyCompletions();

  /// Stores our signed lockup before it is broadcast. Refuses a swap that
  /// already records a lockup or holds a different one being confirmed.
  Future<Result<Swap, SwapsFailure>> recordPendingLockup({
    required String swapId,
    required String signedTx,
  });

  /// Forgets a stored lockup the node refused or that was never sent.
  Future<Result<void, SwapsFailure>> dropPendingLockup(String swapId);

  /// Records our broadcast lockup [txid]. The first recorded lockup is kept.
  Future<Result<Swap, SwapsFailure>> recordLockup({
    required String swapId,
    required String txid,
    int? lockupFeeSat,
  });

  /// Swaps recoverable from the provider with our rescue key.
  Future<Result<List<RestoredSwap>, SwapsFailure>> restore();

  /// Stores a restored swap so it is driven again; funds land in
  /// [walletId] on the swap's acting chain.
  Future<Result<Swap, SwapsFailure>> rescue(
    RestoredSwap restored, {
    required String walletId,
  });
}
