import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/label_exchange_orders_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transaction_order_swaps_usecase.dart';

class GetTransactionsUsecase {
  final SettingsRepository _settingsRepository;
  final WalletTransactionRepository _walletTransactionRepository;
  final BoltzSwapRepository _boltzSwapRepository;
  final PayjoinRepository _payjoinRepository;
  final ExchangeOrderRepository _mainnetExchangeOrderRepository;
  final ExchangeOrderRepository _testnetExchangeOrderRepository;
  final LabelExchangeOrdersUsecase _labelExchangeOrdersUsecase;
  final GetTransactionOrderSwapsUsecase _getTransactionOrderSwapsUsecase;

  GetTransactionsUsecase({
    required this._settingsRepository,
    required this._walletTransactionRepository,
    required this._boltzSwapRepository,
    required this._payjoinRepository,
    required this._mainnetExchangeOrderRepository,
    required this._testnetExchangeOrderRepository,
    required this._labelExchangeOrdersUsecase,
    required this._getTransactionOrderSwapsUsecase,
  });

  Future<List<Transaction>> execute({
    String? walletId,
    bool sync = false,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final environment = settings.environment;
      final orderRepository = environment.isTestnet
          ? _testnetExchangeOrderRepository
          : _mainnetExchangeOrderRepository;

      // Fetch wallet transactions, payjoins, orders and swaps
      final (walletTransactions, payjoins, orders, swaps, loadedOrderSwaps) =
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
        _boltzSwapRepository.getAllSwaps(walletId: walletId),
        _getTransactionOrderSwapsUsecase.execute(walletId: walletId),
      ).wait;
      final orderSwaps = [...loadedOrderSwaps];

      if (orders.isNotEmpty) await _labelExchangeOrdersUsecase.execute();

      // Add related payjoins, swaps and orders to the broadcasted wallet transactions
      //  as they should be linked and form a single Transaction entity.
      // In the future if swaps or orders can also be payjoins, we should do the same
      //  as with wallet transactions with the remaining payjoins and swaps
      //  that are not broadcasted yet. Currently this is not the case yet and so
      //  the only combination we need to handle is that a wallet transaction can
      //  have a payjoin, swap or order associated with it. A combination of a
      //  swap or order and payjoin is not possible currently.
      final broadcastedTransactions = walletTransactions.map((wt) {
        Swap? swap;
        try {
          swap = swaps.firstWhere(
            (s) =>
                (wt.isOutgoing && s.sendTxId == wt.txId) ||
                (wt.isIncoming &&
                    (s.receiveTxId == wt.txId || s.refundTxId == wt.txId)),
          );
        } catch (_) {
          // If no swap is found, it means the transaction is not a swap
          swap = null;
        }
        OrderSwapRecord? orderSwap;
        try {
          orderSwap = orderSwaps.firstWhere(
            (candidate) => candidate.localPayinTransactionId == wt.txId,
          );
          orderSwaps.remove(orderSwap);
        } catch (_) {
          orderSwap = null;
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
          orderSwap: orderSwap,
          payjoin: payjoin,
          order: order,
        );
      }).toList();

      // A single swap can surface multiple on-chain legs in the user's own
      // wallets — most importantly a refunded chain swap, whose lockup output
      // and refund-back land on the SAME wallet. Represent each swap with a
      // single row: its canonical leg (swap.txId — the lockup for send/chain,
      // the claim for receive). Drop the secondary leg (e.g. the refund-back
      // tx) so a refunded swap shows as one transaction, not two.
      final swapLegToKeep = <String, String>{};
      for (final tx in broadcastedTransactions) {
        final s = tx.swap;
        final wtTxId = tx.walletTransaction?.txId;
        if (s == null || wtTxId == null) continue;
        if (s.txId == wtTxId) {
          swapLegToKeep[s.id] = wtTxId; // canonical leg wins
        } else {
          swapLegToKeep.putIfAbsent(s.id, () => wtTxId);
        }
      }
      final dedupedBroadcastedTransactions = broadcastedTransactions.where((
        tx,
      ) {
        final s = tx.swap;
        if (s == null) return true;
        return tx.walletTransaction?.txId == swapLegToKeep[s.id];
      }).toList();

      // Filter out any swaps that are already included in the broadcasted transactions
      // We didn't do it in the previous step like with payjoins because one swap can
      // be associated with multiple transactions (e.g., a chain swap that has both
      // incoming and outgoing transactions). We want to make sure the swap is
      // associated with both the incoming as outgoing transaction, so we do it
      // after the broadcasted transactions are created with any associated swaps.
      for (final tx in dedupedBroadcastedTransactions) {
        if (tx.isSwap) {
          swaps.remove(tx.swap);
        }
      }

      // Combine results of broadcasted transactions, remaining swaps which are
      //  ongoing and remaining payjoins that are unbroadcasted as well
      //  into a single list of Transaction entities.
      return [
        ...dedupedBroadcastedTransactions,
        // A resolved recovered swap with no wallet tx here was only associated
        // via a default/counterpart wallet id; don't show it on that chain.
        ...swaps
            .where((s) => !(s.recovered && s.status.isTerminal))
            .map((s) => Transaction(swap: s)),
        ...orderSwaps.map((orderSwap) => Transaction(orderSwap: orderSwap)),
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
    } catch (e, stackTrace) {
      log.severe(
        message: 'Failed to fetch transactions',
        error: e,
        trace: stackTrace,
      );
      throw Exception('Failed to fetch transactions: $e');
    }
  }
}
