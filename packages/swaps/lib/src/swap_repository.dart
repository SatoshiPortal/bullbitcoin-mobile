import 'package:swaps/src/restored_swap.dart';
import 'package:swaps/src/swap.dart';

/// The swap engine's one interface: the swaps we hold, and the operations on
/// one swap. Implementations own their storage and their backend client;
/// resolve operations ([claim], [refund], [coopSign]) are HIGH-LEVEL — the
/// implementation resolves addresses, estimates fees, chooses cooperative vs
/// script path and records the outcome internally. The [SwapWatcher] is the
/// only caller of the resolve operations; blocs read and rescue, nothing
/// else.
///
/// Trustless swaps (Boltz) implement this today; a trusted implementation
/// (Bull exchange) fits the same surface later.
abstract class SwapRepository {
  bool get isTestnet;

  /// Every persisted swap change, as it happens.
  Stream<Swap> get updates;

  Future<Swap> get(String swapId);
  Stream<Swap> watch(String swapId);
  Future<List<Swap>> all({String? walletId});

  /// Swaps that still need watching: non-terminal, or terminal-without-proof
  /// with funds at risk.
  Future<List<Swap>> ongoing({String? walletId});

  Future<LnReceiveSwap> createLightningReceive({
    required String walletId,
    required int amountSat,
    required bool toLiquid,
    String? description,
  });

  Future<LnSendSwap> createLightningSend({
    required String walletId,
    required String invoice,
    required bool fromLiquid,
  });

  Future<ChainSwap> createChain({
    required String sendWalletId,
    required int amountSat,
    required bool fromLiquid,
    String? receiveWalletId,
    String? externalRecipientAddress,
  });

  /// Broadcasts the claim of [swap]'s counterparty lockup and records the
  /// result. Returns the claim txid.
  Future<String> claim(Swap swap);

  /// Broadcasts the refund of [swap]'s own lockup and records the result.
  /// Returns the refund txid (freshly broadcast, or recovered from an
  /// already-spent lockup verified as ours).
  Future<String> refund(Swap swap);

  /// Provides the counterparty our cooperative-close signature so it can
  /// claim cheaply. Failure is non-fatal (script path remains).
  Future<void> coopSign(Swap swap);

  /// Subscribes [swapIds] to live backend events.
  void listen(List<String> swapIds);

  /// Pulls each swap's current backend status and routes it through the same
  /// pipeline as live events — recovery never depends on event replay.
  Future<void> reconcile(List<String> swapIds);

  /// Retract terminal states recorded without proof (e.g. a claim txid that
  /// never paid us) and reopen the swap so the watcher drives it again.
  Future<void> verifyCompletions();

  /// Swaps recoverable from the swap master key via the backend.
  Future<List<RestoredSwap>> restore();

  /// Re-materialises a restored swap into local storage so the watcher can
  /// drive it. Funds land in [walletId] on the swap's acting chain.
  Future<Swap> rescue(RestoredSwap restored, {required String walletId});
}
