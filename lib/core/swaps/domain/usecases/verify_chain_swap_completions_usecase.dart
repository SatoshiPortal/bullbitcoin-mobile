import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';

/// Re-verifies the recorded claim tx of completed chain swaps against the
/// receiving wallet and retracts the ones that never paid us.
///
/// A swap can be mis-settled by the old vout-0 outspend recovery: "the server
/// lockup is spent" was once taken as proof of our claim, but Boltz spending
/// its own change on the lockup tx — or refunding its own expired lockup —
/// satisfies that check too. The result is a swap stamped `completed` with a
/// stranger's txid as `receiveTxid`, while the user's own lockup sits
/// unrefunded on the sending chain.
///
/// For every completed chain swap whose claim landed in one of our wallets,
/// the recorded `receiveTxid` must exist in that wallet's transaction list.
/// When it doesn't, the txid is retracted (status stays `completed`): the
/// swap then reads as locally unresolved, the restore screen offers the
/// rescue again, and the rescue refund path can bring the funds home.
///
/// Deliberately conservative; a swap is left untouched when:
/// - the claim went to an external address (no wallet to verify against),
/// - the receiving wallet's tx cache is empty (not synced yet — a fresh
///   restore must not mass-retract genuine completions),
/// - nothing was ever locked up (no sendTxid — no funds to rescue),
/// - a refund txid exists (the swap resolved through the refund path).
class VerifyChainSwapCompletionsUsecase {
  final BoltzSwapRepository _swapRepository;
  final WalletTransactionRepository _walletTransactionRepository;

  VerifyChainSwapCompletionsUsecase({
    required this._swapRepository,
    required this._walletTransactionRepository,
  });

  Future<void> execute() async {
    try {
      final swaps = await _swapRepository.getAllSwaps();
      for (final swap in swaps) {
        if (swap is! ChainSwap) continue;
        if (swap.status != SwapStatus.completed) continue;
        if (swap.refundTxid != null) continue;
        if (swap.sendTxid == null) continue;
        final receiveTxid = swap.receiveTxid;
        if (receiveTxid == null) {
          // Completed with funds locked and NO txid recorded at all — either
          // an earlier build already retracted a bogus claim (6.13.2 cleared
          // the txid without reopening) or the completion was never proven.
          // Nothing to verify against a wallet; reopen as refundable so the
          // local refund drive picks it up.
          log.warning(
            '[SwapVerify] ${swap.id} is marked completed with no recorded '
            'claim or refund but funds are locked — reopening as refundable',
          );
          await _swapRepository.updateSwapFields(
            swap.id,
            status: SwapStatus.refundable,
          );
          continue;
        }
        final walletId = swap.receiveWalletId;
        if (walletId == null) {
          log.fine(
            '[SwapVerify] ${swap.id} completed with claim to an external '
            'address — cannot verify $receiveTxid, leaving as is',
          );
          continue;
        }

        try {
          // Sync the receiving wallet first: a stale cache that predates the
          // claim would otherwise read as "claim missing" and falsely
          // retract a genuine completion. If the sync fails (offline), the
          // per-swap catch below skips this swap — never retract on a cache
          // we could not freshen.
          final walletTxs = await _walletTransactionRepository
              .getWalletTransactions(walletId: walletId, sync: true);
          if (walletTxs.isEmpty) {
            log.fine(
              '[SwapVerify] ${swap.id}: wallet $walletId has no cached txs '
              '(not synced yet) — skipping verification',
            );
            continue;
          }
          if (walletTxs.any((tx) => tx.txId == receiveTxid)) {
            log.fine(
              '[SwapVerify] ${swap.id}: claim $receiveTxid verified in '
              'wallet $walletId',
            );
            continue;
          }

          log.warning(
            '[SwapVerify] ${swap.id} is marked completed but its recorded '
            'claim $receiveTxid is not in wallet $walletId — retracting the '
            'txid and reopening as refundable (funds locked, no refund '
            'recorded)',
          );
          // Straight to refundable, not just unresolved: with funds locked
          // (sendTxid) and no refund recorded, the refund is the only action
          // left, and deciding this locally keeps the rescue working when
          // the Boltz API is unreachable (a refundable swap is driven from
          // local state; the on-chain broadcast is the safety net — it fails
          // harmlessly if the lockup is in fact already spent).
          await _swapRepository.updateSwapFields(
            swap.id,
            status: SwapStatus.refundable,
            clearReceiveTxid: true,
          );
        } catch (e) {
          // One swap's failure (e.g. missing wallet metadata) must not stop
          // the sweep over the rest.
          log.warning('[SwapVerify] check failed for ${swap.id}: $e');
        }
      }
      await log.flush();
    } catch (e) {
      // Diagnostics/repair must never break startup.
      log.warning('[SwapVerify] failed: $e');
    }
  }
}
