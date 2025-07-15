import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';

class GetTransactionsUsecase {
  final SettingsRepository _settingsRepository;
  final WalletTransactionRepository _walletTransactionRepository;
  final BoltzSwapRepository _mainnetBoltzSwapRepository;
  final BoltzSwapRepository _testnetBoltzSwapRepository;
  final PayjoinRepository _payjoinRepository;
  final ExchangeOrderRepository _mainnetOrderRepository;
  final ExchangeOrderRepository _testnetOrderRepository;

  GetTransactionsUsecase({
    required SettingsRepository settingsRepository,
    required WalletTransactionRepository walletTransactionRepository,
    required BoltzSwapRepository mainnetBoltzSwapRepository,
    required BoltzSwapRepository testnetBoltzSwapRepository,
    required PayjoinRepository payjoinRepository,
    required ExchangeOrderRepository mainnetOrderRepository,
    required ExchangeOrderRepository testnetOrderRepository,
  }) : _settingsRepository = settingsRepository,
       _walletTransactionRepository = walletTransactionRepository,
       _mainnetBoltzSwapRepository = mainnetBoltzSwapRepository,
       _testnetBoltzSwapRepository = testnetBoltzSwapRepository,
       _payjoinRepository = payjoinRepository,
       _mainnetOrderRepository = mainnetOrderRepository,
       _testnetOrderRepository = testnetOrderRepository;

  Future<List<Transaction>> execute({
    String? walletId,
    bool sync = false,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final environment = settings.environment;
      final swapRepository =
          environment.isTestnet
              ? _testnetBoltzSwapRepository
              : _mainnetBoltzSwapRepository;
      final orderRepository =
          environment.isTestnet
              ? _testnetOrderRepository
              : _mainnetOrderRepository;

      // Fetch wallet transactions, payjoins, orders and swaps
      final (walletTransactions, payjoins, orders, swaps) =
          await (
            _walletTransactionRepository.getWalletTransactions(
              walletId: walletId,
              sync: sync,
              environment: environment,
            ),
            _payjoinRepository.getPayjoins(
              walletId: walletId,
              environment: environment,
            ),
            orderRepository.getOrders(),
            swapRepository.getAllSwaps(walletId: walletId),
          ).wait;

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
            Swap? swap;
            try {
              swap = swaps.firstWhere(
                (s) =>
                    (wt.isOutgoing && s.sendTxId == wt.txId) ||
                    (wt.isIncoming && s.receiveTxId == wt.txId),
              );
            } catch (_) {
              // If no swap is found, it means the transaction is not a swap
              swap = null;
            }
            Payjoin? payjoin;
            try {
              payjoin = payjoins.firstWhere(
                (pj) =>
                    [pj.txId, pj.originalTxId].contains(wt.txId) &&
                    // Make sure to match the direction of the payjoin, since
                    //  both a sender and receiver payjoin can exist for the
                    //  same transaction if it was done between two wallets in
                    //  the app.
                    wt.isOutgoing == pj is PayjoinSender,
              );
              // Remove the payjoin from the list of payjoins to avoid duplication
              //  since it's already included in the broadcasted transaction
              payjoins.remove(payjoin);
            } catch (_) {
              // If no payjoin is found, it means the transaction is not a payjoin
              payjoin = null;
            }

            Order? order;
            try {
              order = orders.firstWhere((o) => o.transactionId == wt.txId);
              // Remove the order from the list of orders to avoid duplication
              //  since it's already included in the broadcasted transaction
              orders.remove(order);
            } catch (_) {
              // If no order is found, it means the transaction is not an order
              order = null;
            }

            return Transaction(
              walletTransaction: wt,
              swap: swap,
              payjoin: payjoin,
              order: order,
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
        // If walletId is not null, the orders should be linked to a wallet transaction.
        // TODO: We could still check on the address of the order to see if it
        // is related to the wallet id, even without a wallet transaction yet.
        //  Another option is to persist order data and include the wallet id
        //  there already so it can be linked easily. The latter might be the
        //  most efficient and robust way for the future. But for now we assume that
        //  orders without a wallet transaction are not relevant for a specific wallet yet.
        ...(walletId == null
            ? orders.map((o) => Transaction(order: o))
            : <Transaction>[]),
      ];
    } catch (e) {
      throw Exception('Failed to fetch transactions: $e');
    }
  }
}
