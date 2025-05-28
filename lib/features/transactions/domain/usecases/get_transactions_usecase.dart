import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';

class GetTransactionsUsecase {
  final SettingsRepository _settingsRepository;
  final WalletTransactionRepository _walletTransactionRepository;
  final SwapRepository _mainnetSwapRepository;
  final SwapRepository _testnetSwapRepository;
  final PayjoinRepository _payjoinRepository;

  GetTransactionsUsecase({
    required SettingsRepository settingsRepository,
    required WalletTransactionRepository walletTransactionRepository,
    required SwapRepository mainnetSwapRepository,
    required SwapRepository testnetSwapRepository,
    required PayjoinRepository payjoinRepository,
  }) : _settingsRepository = settingsRepository,
       _walletTransactionRepository = walletTransactionRepository,
       _mainnetSwapRepository = mainnetSwapRepository,
       _testnetSwapRepository = testnetSwapRepository,
       _payjoinRepository = payjoinRepository;

  Future<List<Transaction>> execute({
    String? walletId,
    bool sync = false,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final environment = settings.environment;

      // Fetch wallet transactions
      final walletTransactions = await _walletTransactionRepository
          .getWalletTransactions(
            walletId: walletId,
            sync: sync,
            environment: environment,
          );

      // Fetch payjoin transactions
      final payjoins = await _payjoinRepository.getPayjoins(
        walletId: walletId,
        environment: environment,
      );

      // Fetch swaps
      final swaps =
          environment.isTestnet
              ? await _testnetSwapRepository.getAllSwaps(walletId: walletId)
              : await _mainnetSwapRepository.getAllSwaps(walletId: walletId);

      final broadcastedTransactions = walletTransactions.map((wt) {
        final swap =
            swaps
                .where(
                  (swap) =>
                      (wt.isOutgoing && swap.sendTxId == wt.txId) ||
                      (wt.isIncoming && swap.receiveTxId == wt.txId),
                )
                .firstOrNull;
        final payjoin =
            payjoins
                .where(
                  (pj) =>
                      [pj.txId, pj.originalTxId].contains(wt.txId) &&
                      // Make sure to match the direction of the payjoin, since
                      //  both a sender and receiver payjoin can exist for the
                      //  same transaction if it was done between two wallets in
                      //  the app.
                      wt.isOutgoing == pj is PayjoinSender,
                )
                .firstOrNull;
        if (payjoin != null) {
          // Remove the payjoin from the list of payjoins to avoid duplication
          //  since it's already included in the broadcasted transaction
          payjoins.remove(payjoin);
        }

        return Transaction.broadcasted(
          walletTransaction: wt,
          swap: swap,
          payjoin: payjoin,
        );
      });

      // Filter out any swaps that are already included in the broadcasted transactions
      // We didn't do it in the previous step like with payjoins because one swap can
      // be associated with multiple transactions (e.g., a chain swap that has both
      // incoming and outgoing transactions). We want to make sure the swap is
      // associated with both the incoming as outgoing transaction, so we do it
      // after the broadcasted transactions are created with any associated swaps.
      for (final tx in broadcastedTransactions) {
        if (tx.isSwap) {
          swaps.remove(tx.swap);
        }
      }

      // Combine results into a list of Transaction entities
      return [
        ...broadcastedTransactions,
        ...swaps.map((s) => Transaction.ongoingSwap(swap: s)),
        ...payjoins.map((p) => Transaction.ongoingPayjoin(payjoin: p)),
      ];
    } catch (e) {
      throw Exception('Failed to fetch transactions: $e');
    }
  }
}
