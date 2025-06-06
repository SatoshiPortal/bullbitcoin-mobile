import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
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
  final ExchangeOrderRepository _orderRepository;

  GetTransactionsUsecase({
    required SettingsRepository settingsRepository,
    required WalletTransactionRepository walletTransactionRepository,
    required SwapRepository mainnetSwapRepository,
    required SwapRepository testnetSwapRepository,
    required PayjoinRepository payjoinRepository,
    required ExchangeOrderRepository orderRepository,
  }) : _settingsRepository = settingsRepository,
       _walletTransactionRepository = walletTransactionRepository,
       _mainnetSwapRepository = mainnetSwapRepository,
       _testnetSwapRepository = testnetSwapRepository,
       _payjoinRepository = payjoinRepository,
       _orderRepository = orderRepository;

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

      // Fetch orders
      final orders = await _orderRepository.getOrders();

      // Fetch swaps
      final swaps =
          environment.isTestnet
              ? await _testnetSwapRepository.getAllSwaps(walletId: walletId)
              : await _mainnetSwapRepository.getAllSwaps(walletId: walletId);

      // Add related payjoins, swaps and orders to the broadcasted wallet transactions
      //  as they should be linked and form a single Transaction entity.
      // In the future if swaps or orders can also be payjoins, we should do the same
      //  as with wallet transactions with the remaining payjoins and swaps
      //  that are not broadcasted yet. Currently this is not the case yet and so
      //  the only combination we need to handle is that a wallet transaction can
      //  have a payjoin, swap or order associated with it. A combination of a
      //  swap or order and payjoin is not possible currently.
      final broadcastedTransactions =
          walletTransactions.map((wt) {
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
            final order =
                orders.where((o) => o.transactionId == wt.txId).firstOrNull;
            if (order != null) {
              // Remove the order from the list of orders to avoid duplication
              //  since it's already included in the broadcasted transaction
              orders.remove(order);
            }

            return Transaction(
              walletTransaction: wt,
              swap: swap,
              payjoin: payjoin,
            );
          }).toList();

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

      // Combine results of broadcasted transactions, remaining swaps which are
      //  ongoing and remaining payjoins that are unbroadcasted as well
      //  into a single list of Transaction entities.
      return [
        ...broadcastedTransactions,
        ...swaps.map((s) => Transaction(swap: s)),
        ...payjoins.map((p) => Transaction(payjoin: p)),
        ...orders.map((o) => Transaction(order: o)),
      ];
    } catch (e) {
      throw Exception('Failed to fetch transactions: $e');
    }
  }
}
