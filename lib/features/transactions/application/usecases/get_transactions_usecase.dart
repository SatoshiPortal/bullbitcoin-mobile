import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_history_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/transactions/application/usecases/label_exchange_orders_usecase.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transaction_order_swaps_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/order_swap_transaction_match.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';

class GetTransactionsUsecase {
  final SettingsRepository _settingsRepository;
  final WalletTransactionRepository _walletTransactionRepository;
  final SwapHistoryRepository _boltzSwapRepository;
  final PayjoinSessions _payjoinSessions;
  final ExchangeOrderRepository _mainnetExchangeOrderRepository;
  final ExchangeOrderRepository _testnetExchangeOrderRepository;
  final LabelExchangeOrdersUsecase _labelExchangeOrdersUsecase;
  final GetTransactionOrderSwapsUsecase _getTransactionOrderSwapsUsecase;

  GetTransactionsUsecase({
    required this._settingsRepository,
    required this._walletTransactionRepository,
    required this._boltzSwapRepository,
    required this._payjoinSessions,
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

      final orders = await orderRepository.getOrders();
      await _labelExchangeOrdersUsecase.execute(orders: orders);

      // Labels must exist before wallet transactions are hydrated.
      final (
        walletTransactions,
        payjoinResult,
        swaps,
        loadedOrderSwaps,
      ) = await (
        _walletTransactionRepository.getWalletTransactions(
          walletId: walletId,
          sync: sync,
          environment: environment,
        ),
        _payjoinSessions.list(
          PayjoinSessionFilter(
            walletId: walletId,
            network: environment.isTestnet
                ? BitcoinNetwork.testnet
                : BitcoinNetwork.mainnet,
          ),
        ),
        _boltzSwapRepository.getAllSwaps(walletId: walletId),
        _getTransactionOrderSwapsUsecase.execute(walletId: walletId),
      ).wait;
      final payjoins = switch (payjoinResult) {
        Ok(:final value) => value,
        Err() => <PayjoinSession>[],
      };
      final orderSwaps = [...loadedOrderSwaps];
      final canonicalOrderSwaps = <OrderSwapWalletLeg, OrderSwapRecord>{};
      final secondaryOrderSwapLegs = <OrderSwapWalletLeg>{};
      for (final orderSwap in loadedOrderSwaps) {
        final canonical = canonicalOrderSwapWalletLeg(orderSwap);
        if (canonical != null) canonicalOrderSwaps[canonical] = orderSwap;
        secondaryOrderSwapLegs.addAll(secondaryOrderSwapWalletLegs(orderSwap));
      }

      final swapBuckets = <String, List<int>>{};
      for (var index = 0; index < swaps.length; index++) {
        final swap = swaps[index];
        for (final txId in {swap.sendTxId, swap.receiveTxId, swap.refundTxId}) {
          if (txId != null) swapBuckets.putIfAbsent(txId, () => []).add(index);
        }
      }
      final payjoinBuckets = <String, List<int>>{};
      for (var index = 0; index < payjoins.length; index++) {
        final payjoin = payjoins[index];
        for (final txId in {payjoin.txId, payjoin.originalTxId}) {
          if (txId != null) {
            payjoinBuckets.putIfAbsent(txId, () => []).add(index);
          }
        }
      }
      final orderBuckets = <String, List<int>>{};
      for (var index = 0; index < orders.length; index++) {
        final txId = orders[index].transactionId;
        if (txId != null) orderBuckets.putIfAbsent(txId, () => []).add(index);
      }
      final consumedPayjoinIndices = <int>{};
      final consumedOrderIndices = <int>{};
      final consumedOrderSwapIndices = <int>{};
      final orderSwapIndexQueues = <OrderSwapRecord, List<int>>{};
      final nextOrderSwapQueueIndices = <OrderSwapRecord, int>{};
      for (var index = 0; index < orderSwaps.length; index++) {
        orderSwapIndexQueues
            .putIfAbsent(orderSwaps[index], () => [])
            .add(index);
      }

      // Add related payjoins, swaps and orders to the broadcasted wallet transactions
      //  as they should be linked and form a single Transaction entity.
      // In the future if swaps or orders can also be payjoins, we should do the same
      //  as with wallet transactions with the remaining payjoins and swaps
      //  that are not broadcasted yet. Currently this is not the case yet and so
      //  the only combination we need to handle is that a wallet transaction can
      //  have a payjoin, swap or order associated with it. A combination of a
      //  swap or order and payjoin is not possible currently.
      final broadcastedTransactions = walletTransactions
          .map((wt) {
            Swap? swap;
            for (final index in swapBuckets[wt.txId] ?? const <int>[]) {
              final s = swaps[index];
              final claimedLeg =
                  (wt.isOutgoing && s.sendTxId == wt.txId) ||
                  (wt.isIncoming &&
                      (s.receiveTxId == wt.txId || s.refundTxId == wt.txId));
              if (claimedLeg &&
                  s.walletId == wt.walletId &&
                  (s.amountSat == 0 || wt.amountSat <= s.amountSat) &&
                  _transactionPaysSwapAddress(wt, s)) {
                swap = s;
                break;
              }
            }
            final orderSwap =
                canonicalOrderSwaps[(txId: wt.txId, walletId: wt.walletId)];
            if (orderSwap != null) {
              final queue = orderSwapIndexQueues[orderSwap];
              final queueIndex = nextOrderSwapQueueIndices[orderSwap] ?? 0;
              if (queue != null && queueIndex < queue.length) {
                consumedOrderSwapIndices.add(queue[queueIndex]);
                nextOrderSwapQueueIndices[orderSwap] = queueIndex + 1;
              }
            }
            PayjoinSession? payjoin;
            for (final index in payjoinBuckets[wt.txId] ?? const <int>[]) {
              if (consumedPayjoinIndices.contains(index)) continue;
              final candidate = payjoins[index];
              if ((candidate.txId == wt.txId ||
                      candidate.originalTxId == wt.txId) &&
                  // Make sure to match the direction of the payjoin, since
                  //  both a sender and receiver payjoin can exist for the
                  //  same transaction if it was done between two wallets in
                  //  the app.
                  wt.isOutgoing == candidate is PayjoinSenderSession) {
                payjoin = candidate;
                consumedPayjoinIndices.add(index);
                break;
              }
            }

            Order? order;
            for (final index in orderBuckets[wt.txId] ?? const <int>[]) {
              if (consumedOrderIndices.contains(index)) continue;
              final o = orders[index];
              if (o.toAddress != null && o.toAddress != wt.toAddress) {
                continue;
              }
              final expectedDirection = o is BuyOrder
                  ? wt.isIncoming
                  : o is SellOrder
                  ? wt.isOutgoing
                  : true;
              if (expectedDirection && _transactionCoversOrderAmount(wt, o)) {
                order = o;
                consumedOrderIndices.add(index);
                break;
              }
            }

            return Transaction(
              walletTransaction: wt,
              swap: swap,
              orderSwap: orderSwap,
              payjoin: payjoin,
              order: order,
            );
          })
          .where((transaction) {
            if (transaction.orderSwap != null) return true;
            final walletTransaction = transaction.walletTransaction;
            if (walletTransaction == null) return true;
            return !secondaryOrderSwapLegs.contains((
              txId: walletTransaction.txId,
              walletId: walletTransaction.walletId,
            ));
          })
          .toList();

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
      final consumedSwapIndices = <int>{};
      final swapIndexQueues = <Swap, List<int>>{};
      final nextSwapQueueIndices = <Swap, int>{};
      for (var index = 0; index < swaps.length; index++) {
        swapIndexQueues.putIfAbsent(swaps[index], () => []).add(index);
      }
      for (final tx in dedupedBroadcastedTransactions) {
        if (tx.isSwap) {
          final swap = tx.swap;
          if (swap == null) continue;
          final queue = swapIndexQueues[swap];
          if (queue == null) continue;
          final queueIndex = nextSwapQueueIndices[swap] ?? 0;
          if (queueIndex < queue.length) {
            consumedSwapIndices.add(queue[queueIndex]);
            nextSwapQueueIndices[swap] = queueIndex + 1;
          }
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
            .asMap()
            .entries
            .where(
              (entry) =>
                  !consumedSwapIndices.contains(entry.key) &&
                  !(entry.value.recovered && entry.value.status.isTerminal),
            )
            .map((entry) => entry.value)
            .map((s) => Transaction(swap: s)),
        // An aborted Payjoin means its original transaction was successfully
        // broadcast or observed. If that wallet transaction is not visible in
        // this fetch yet, do not render the terminal session as a second
        // standalone `0 sats / pending` row; the real transaction will be
        // joined through originalTxId once wallet sync catches up.
        ...payjoins
            .asMap()
            .entries
            .where(
              (entry) =>
                  !consumedPayjoinIndices.contains(entry.key) &&
                  !entry.value.isAborted,
            )
            .map((entry) => entry.value)
            .map((p) => Transaction(payjoin: p)),
        ...orderSwaps
            .asMap()
            .entries
            .where((entry) => !consumedOrderSwapIndices.contains(entry.key))
            .map((entry) => Transaction(orderSwap: entry.value)),
        // If walletId is not null, the orders should be linked to a wallet transaction.
        // TODO: We could still check on the address of the order to see if it
        // is related to the wallet id, even without a wallet transaction yet.
        //  Another option is to persist order data and include the wallet id
        //  there already so it can be linked easily. The latter might be the
        //  most efficient and robust way for the future. But for now we assume that
        //  orders without a wallet transaction are not relevant for a specific wallet yet.
        ...(walletId == null
            ? orders
                  .asMap()
                  .entries
                  .where((entry) => !consumedOrderIndices.contains(entry.key))
                  .map((entry) => Transaction(order: entry.value))
            : <Transaction>[]),
      ];
    } catch (e, stackTrace) {
      log.severe(
        message: 'Failed to fetch transactions',
        error: e,
        trace: stackTrace,
      );
      throw TransactionAggregationFailure(e.toString());
    }
  }

  /// The exchange tells us which address a completed order paid. Before the
  /// order is attached to one of the user's transactions, that transaction
  /// must actually have moved at least what the order claims — otherwise a
  /// wrong or hostile server figure gets attributed to unrelated funds.
  ///
  /// `>=` rather than `==` on purpose: payouts are batched, so one transaction
  /// can legitimately carry several orders and more sats than a single one.
  bool _transactionCoversOrderAmount(WalletTransaction wt, Order order) {
    final double declared;
    switch (order) {
      case BuyOrder(:final payoutAmount, :final payoutCurrency):
        if (payoutCurrency != 'BTC') return true;
        declared = payoutAmount;
      case SellOrder(:final payinAmount, :final payinCurrency):
        if (payinCurrency != 'BTC') return true;
        declared = payinAmount;
      default:
        return true;
    }
    if (!declared.isFinite) return false;
    final declaredSat = ConvertAmount.btcToSats(declared);
    if (declaredSat <= 0) return true;
    return wt.amountSat >= declaredSat;
  }

  /// A swap leg is only this transaction's if the transaction actually pays
  /// the address the swap is built around. Matching on the server-reported
  /// txid alone lets a wrong id graft a swap onto an unrelated payment.
  bool _transactionPaysSwapAddress(WalletTransaction wt, Swap swap) {
    // Liquid outputs expose the unconfidential address while a swap address is
    // confidential, so the two are not comparable here; the txid + wallet +
    // amount checks remain. TODO(swaps): unblind before comparing.
    if (!wt.isBitcoin) return true;

    final expected = <String>{
      if (wt.isOutgoing)
        ...switch (swap) {
          LnSendSwap(:final paymentAddress) => [paymentAddress],
          ChainSwap(:final paymentAddress) => [paymentAddress],
          _ => <String>[],
        },
      if (wt.isIncoming)
        ...switch (swap) {
          LnReceiveSwap(:final receiveAddress) => [?receiveAddress],
          ChainSwap(:final receiveAddress, :final refundAddress) => [
            ?receiveAddress,
            ?refundAddress,
          ],
          LnSendSwap(:final refundAddress) => [?refundAddress],
        },
    };
    // Nothing to compare against (a recovered swap carries no address): fall
    // back to the other checks rather than dropping a legitimate leg.
    if (expected.isEmpty) return true;

    return wt.outputs.any(
      (output) => output.address != null && expected.contains(output.address),
    );
  }
}
