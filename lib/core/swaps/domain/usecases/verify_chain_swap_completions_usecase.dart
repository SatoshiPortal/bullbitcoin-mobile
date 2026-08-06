import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';

/// Re-verifies the recorded claim tx of completed chain swaps against the
/// receiving wallet and retracts the ones that never paid us.
///
/// A swap can be mis-settled by the on-chain outspend recovery: "the server
/// lockup is spent" was once taken as proof of our claim, but Boltz spending
/// its own change on the lockup tx — or refunding its own expired lockup —
/// satisfies that check too. The result is a swap stamped `completed` with a
/// stranger's txid as `receiveTxid`, which keeps it out of the watch set
/// forever while the user's own lockup sits unrefunded on the sending chain.
///
/// For every completed chain swap whose claim landed in one of our wallets,
/// the recorded `receiveTxid` must exist in that wallet's transaction list.
/// When it doesn't, the txid is retracted (status stays `completed`): a
/// completed chain swap with no recorded txids re-enters `getOngoingSwaps`'
/// watch set, reconciliation fetches the real Boltz status, and the normal
/// pipeline takes over — e.g. `transaction.refunded` makes it refundable and
/// the watcher broadcasts the refund.
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
    required BoltzSwapRepository boltzSwapRepository,
    required this._walletTransactionRepository,
  }) : _swapRepository = boltzSwapRepository;

  Future<void> execute() async {
    try {
      final swaps = await _swapRepository.getAllSwaps();
      for (final swap in swaps) {
        if (swap is! ChainSwap) continue;
        if (swap.status != SwapStatus.completed) continue;
        final receiveTxid = swap.receiveTxid;
        if (receiveTxid == null || swap.refundTxid != null) continue;
        if (swap.sendTxid == null) continue;
        final walletId = swap.receiveWalletId;
        if (walletId == null) continue;

        try {
          final walletTxs = await _walletTransactionRepository
              .getWalletTransactions(walletId: walletId);
          if (walletTxs.isEmpty) continue;
          if (walletTxs.any((tx) => tx.txId == receiveTxid)) continue;

          log.warning(
            '[SwapVerify] ${swap.id} is marked completed but its recorded '
            'claim $receiveTxid is not in wallet $walletId — retracting the '
            'txid so the swap re-enters the watch set',
          );
          await _swapRepository.updateSwapFields(
            swap.id,
            clearReceiveTxid: true,
          );
        } catch (e) {
          // One swap's failure (e.g. missing wallet metadata) must not stop
          // the sweep over the rest.
          log.warning('[SwapVerify] check failed for ${swap.id}: $e');
        }
      }
    } catch (e) {
      // Diagnostics/repair must never break startup.
      log.warning('[SwapVerify] failed: $e');
    }
  }
}
