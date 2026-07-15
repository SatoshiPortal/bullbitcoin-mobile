import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/usecases/get_order_usercase.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/broadcast_original_transaction_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/get_payjoin_by_id_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/process_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_transaction_by_tx_id_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_error.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transactions_by_tx_id_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_details_cubit.freezed.dart';
part 'transaction_details_state.dart';

class TransactionDetailsCubit extends Cubit<TransactionDetailsState> {
  TransactionDetailsCubit({
    required this._getWalletUsecase,
    required this._getTransactionsByTxIdUsecase,
    required this._watchWalletTransactionByTxIdUsecase,
    required this._getSwapUsecase,
    required this._getPayjoinByIdUsecase,
    required this._getOrderUsecase,
    required this._watchSwapUsecase,
    required this._watchPayjoinUsecase,
    required this._labelsFacade,
    required this._broadcastOriginalTransactionUsecase,
    required this._processSwapUsecase,
  }) : super(const TransactionDetailsState());

  final GetWalletUsecase _getWalletUsecase;
  final GetTransactionsByTxIdUsecase _getTransactionsByTxIdUsecase;
  final WatchWalletTransactionByTxIdUsecase
  _watchWalletTransactionByTxIdUsecase;
  final GetSwapUsecase _getSwapUsecase;
  final GetPayjoinByIdUsecase _getPayjoinByIdUsecase;
  final GetOrderUsecase _getOrderUsecase;
  final WatchSwapUsecase _watchSwapUsecase;
  final WatchPayjoinUsecase _watchPayjoinUsecase;
  final LabelsFacade _labelsFacade;
  final BroadcastOriginalTransactionUsecase
  _broadcastOriginalTransactionUsecase;
  final ProcessSwapUsecase _processSwapUsecase;

  StreamSubscription? _walletTransactionSubscription;
  StreamSubscription? _swapSubscription;
  StreamSubscription? _payjoinSubscription;
  StreamSubscription? _payjoinTxSubscription;
  StreamSubscription? _payjoinOriginalTxSubscription;

  @override
  Future<void> close() async {
    await Future.wait([
      _walletTransactionSubscription?.cancel() ?? Future.value(),
      _swapSubscription?.cancel() ?? Future.value(),
      _payjoinSubscription?.cancel() ?? Future.value(),
      _payjoinTxSubscription?.cancel() ?? Future.value(),
      _payjoinOriginalTxSubscription?.cancel() ?? Future.value(),
    ]);
    return super.close();
  }

  Future<void> initByWalletTxId(String txId, {required String walletId}) async {
    // Start monitoring the wallet transaction for updates.
    _walletTransactionSubscription = _watchWalletTransactionByTxIdUsecase
        .execute(txId: txId, walletId: walletId)
        .listen((_) => _loadDetailsByWalletTxId(txId, walletId: walletId));

    // Load the initial details of the transaction.
    await _loadDetailsByWalletTxId(txId, walletId: walletId);
  }

  Future<void> _loadDetailsByWalletTxId(
    String txId, {
    required String walletId,
  }) async {
    try {
      final transactionsWithTxId = await _getTransactionsByTxIdUsecase.execute(
        txId,
      );
      final transaction = transactionsWithTxId.firstWhere(
        (tx) => tx.walletId == walletId,
        orElse: () => throw TransactionNotFoundError(),
      );
      final wallet = await _getWalletUsecase.execute(walletId);

      Wallet? counterpartWallet;
      final swap = transaction.swap;
      String? swapCounterpartTxId;
      // Retain only transactions that are not the same wallet and
      // have the opposite isIncoming value.
      // This is to find the counterpart wallet for the transaction.
      transactionsWithTxId.retainWhere(
        (t) => t.walletId != walletId && t.isIncoming != transaction.isIncoming,
      );
      if (transactionsWithTxId.isNotEmpty) {
        // If a transaction is found, get the wallet for it.
        counterpartWallet = await _getWalletUsecase.execute(
          transactionsWithTxId.first.walletId,
        );
      } else if (swap is ChainSwap) {
        swapCounterpartTxId = walletId == swap.sendWalletId
            ? swap.receiveTxId
            : swap.sendTxId;
        final counterpartWalletId = walletId == swap.sendWalletId
            ? swap.receiveWalletId
            : swap.sendWalletId;
        if (counterpartWalletId != null) {
          counterpartWallet = await _getWalletUsecase.execute(
            counterpartWalletId,
          );
        }
      }

      emit(
        state.copyWith(
          transaction: transaction,
          wallet: wallet,
          counterpartWallet: counterpartWallet,
          swapCounterpartTxId: swapCounterpartTxId,
          swapClaimedAmountSat: await _counterpartAmountForSwap(swap),
        ),
      );
    } on TransactionNotFoundError catch (e) {
      emit(state.copyWith(notFoundError: e));
    } catch (e) {
      emit(state.copyWith(err: e));
    }
  }

  /// The exact amount returned on the recovered chain swap's *counterpart* leg —
  /// what the user actually received. The canonical tx shown from the send
  /// wallet is the lockup leg (its amount is what was SENT), so the received
  /// figure comes from the other leg: the claim tx on a forward swap, or the
  /// refund tx on a refunded swap. Returns null when not a recovered chain swap
  /// or that leg isn't available yet.
  Future<int?> _counterpartAmountForSwap(Swap? swap) async {
    return await _claimedAmountForSwap(swap) ??
        await _refundedAmountForSwap(swap);
  }

  /// Forward (claim) leg: `receiveTxId` in the receive wallet.
  Future<int?> _claimedAmountForSwap(Swap? swap) async {
    if (swap is! ChainSwap || !swap.recovered) return null;
    final receiveTxId = swap.receiveTxId;
    final receiveWalletId = swap.receiveWalletId;
    if (receiveTxId == null || receiveWalletId == null) return null;
    return _amountForTxInWallet(receiveTxId, receiveWalletId);
  }

  /// Refund leg: the refund spends the lockup back to the SOURCE (send) chain,
  /// so the returned amount is the refund tx's incoming amount in the send
  /// wallet (lockup minus the refund tx fee).
  Future<int?> _refundedAmountForSwap(Swap? swap) async {
    if (swap is! ChainSwap || !swap.recovered) return null;
    final refundTxId = swap.refundTxId;
    if (refundTxId == null) return null;
    return _amountForTxInWallet(refundTxId, swap.sendWalletId);
  }

  Future<int?> _amountForTxInWallet(String txId, String walletId) async {
    try {
      final txs = await _getTransactionsByTxIdUsecase.execute(txId);
      for (final t in txs) {
        if (t.walletId == walletId) {
          return t.walletTransaction?.amountSat;
        }
      }
      return txs.isEmpty ? null : txs.first.walletTransaction?.amountSat;
    } catch (_) {
      return null;
    }
  }

  Future<void> initBySwapId(String swapId, {required String walletId}) async {
    _swapSubscription = _watchSwapUsecase
        .execute(swapId)
        .listen((_) => _loadDetailsBySwapId(swapId, walletId: walletId));

    // Load the initial details of the swap.
    await _loadDetailsBySwapId(swapId, walletId: walletId);
  }

  Future<void> _loadDetailsBySwapId(
    String swapId, {
    required String walletId,
  }) async {
    try {
      final swap = await _getSwapUsecase.execute(swapId);

      String? txId;
      if (swap is ChainSwap) {
        // For chain swaps, we need to get the transaction ID based on the wallet ID,
        //  since we need to show the transaction from the correct perspective/direction.
        txId = walletId == swap.sendWalletId ? swap.sendTxId : swap.receiveTxId;
      } else {
        // For other swaps, we can use the swap's transaction ID directly.
        txId = swap.txId;
      }

      if (txId != null) {
        await _swapSubscription?.cancel();
        await initByWalletTxId(txId, walletId: walletId);
        return;
      }

      final wallet = await _getWalletUsecase.execute(walletId);

      Wallet? counterpartWallet;
      String? swapCounterpartTxId;
      if (swap is ChainSwap) {
        swapCounterpartTxId = walletId == swap.sendWalletId
            ? swap.receiveTxId
            : swap.sendTxId;
        final counterpartWalletId = walletId == swap.sendWalletId
            ? swap.receiveWalletId
            : swap.sendWalletId;
        if (counterpartWalletId != null) {
          counterpartWallet = await _getWalletUsecase.execute(
            counterpartWalletId,
          );
        }
      }

      emit(
        state.copyWith(
          transaction: Transaction(swap: swap),
          wallet: wallet,
          counterpartWallet: counterpartWallet,
          swapCounterpartTxId: swapCounterpartTxId,
        ),
      );
    } catch (e) {
      emit(state.copyWith(err: e));
    }
  }

  Future<void> initByPayjoinId(String payjoinId) async {
    _payjoinSubscription = _watchPayjoinUsecase
        .execute(ids: [payjoinId])
        .listen((_) => _loadDetailsByPayjoinId(payjoinId));

    // Load the initial details of the payjoin.
    await _loadDetailsByPayjoinId(payjoinId);
  }

  Future<void> _loadDetailsByPayjoinId(String payjoinId) async {
    try {
      final payjoin = await _getPayjoinByIdUsecase.execute(payjoinId);

      if (payjoin.txId != null) {
        // Listen for the payjoin transaction to be broadcasted.
        await _payjoinTxSubscription?.cancel();
        _payjoinTxSubscription = _watchWalletTransactionByTxIdUsecase
            .execute(txId: payjoin.txId!, walletId: payjoin.walletId)
            .listen((_) async {
              await _payjoinSubscription?.cancel();
              await _loadDetailsByWalletTxId(
                payjoin.txId!,
                walletId: payjoin.walletId,
              );
            });
      }
      if (payjoin.originalTxId != null) {
        // Listen for the payjoin original transaction to be broadcasted.
        await _payjoinOriginalTxSubscription?.cancel();
        _payjoinOriginalTxSubscription = _watchWalletTransactionByTxIdUsecase
            .execute(txId: payjoin.originalTxId!, walletId: payjoin.walletId)
            .listen((_) async {
              await _payjoinSubscription?.cancel();
              await _loadDetailsByWalletTxId(
                payjoin.originalTxId!,
                walletId: payjoin.walletId,
              );
            });
      }

      final wallet = await _getWalletUsecase.execute(payjoin.walletId);
      emit(
        state.copyWith(
          transaction: Transaction(payjoin: payjoin),
          wallet: wallet,
        ),
      );
    } catch (e) {
      emit(state.copyWith(err: e));
    }
  }

  Future<void> initByOrderId(String orderId) async {
    await _loadDetailsByOrderId(orderId);
  }

  Future<void> _loadDetailsByOrderId(String orderId) async {
    try {
      final order = await _getOrderUsecase.execute(orderId: orderId);

      // Check if a transaction with the same transaction ID can be found
      // and initialize the transaction details with it.
      final txId = order.transactionId;
      if (txId != null) {
        try {
          final txs = await _getTransactionsByTxIdUsecase.execute(txId);
          await initByWalletTxId(txId, walletId: txs.first.walletId);
          return;
        } catch (e) {
          // If an error occurs while fetching transactions, we can ignore it
          // and proceed with just the order details.
        }
      }

      emit(state.copyWith(transaction: Transaction(order: order)));
    } catch (e) {
      emit(state.copyWith(err: e));
    }
  }

  Future<void> saveTransactionLabel(NewLabel label) async {
    // TODO: Permit multiple labels && labels for payjoin txs, so not only wallet txs (for example set on the original tx)
    //  I think the entity should be changed to Transaction instead of WalletTransaction for that
    if (state.walletTransaction == null) return;

    if (state.walletTransaction!.labels.length >= 10) {
      emit(state.copyWith(err: 'You can only have up to 10 labels'));
      return;
    }

    final txLabel = NewLabel.tx(
      transactionId: state.walletTransaction!.txId,
      label: label.label,
      origin: state.walletTransaction!.walletId,
    );
    final Label storedLabel;
    switch (await _labelsFacade.store(txLabel)) {
      case Ok(:final value):
        storedLabel = value;
      case Err():
        // Persisting the note failed (logged at the boundary); leave the UI
        // unchanged rather than render an unsaved label as saved.
        return;
    }

    final updatedWalletransaction = state.transaction?.walletTransaction
        ?.copyWith(
          labels: [
            ...?state.transaction?.walletTransaction?.labels,
            storedLabel,
          ],
        );
    emit(
      state.copyWith(
        transaction: state.transaction?.copyWith(
          walletTransaction: updatedWalletransaction,
        ),
      ),
    );
  }

  Future<void> broadcastPayjoinOriginalTx() async {
    try {
      final payjoin = state.payjoin;
      if (payjoin == null) return;
      // Backstop mirroring PayjoinRepositoryImpl.tryBroadcastOriginalTransaction's
      // own guard: once the session already resolved (real payjoin or an
      // earlier fallback broadcast) or a proposal is still being actively
      // processed, a manual rebroadcast of the original here would either be
      // a no-op or, worse, race/replace an already-broadcast real payjoin
      // transaction that spends the same inputs at a different fee. The UI
      // is expected to already hide this button in that case (see
      // TransactionDetailsScreen's `!isPayjoinCompleted` gate); this is the
      // backstop against a stale snapshot letting a tap through anyway —
      // observed live (a second "Send without payjoin" tap re-broadcast an
      // already-completed session's original transaction). `!isExpired` is
      // required alongside proposalPsbt != null (not just proposalPsbt !=
      // null alone): if the repository's OWN internal fallback already tried
      // and ALSO failed, the session is marked isExpired with nothing left
      // to retry it automatically — a manual retry must still be possible.
      if (payjoin.isCompleted ||
          (payjoin.proposalPsbt != null && !payjoin.isExpired)) {
        return;
      }
      emit(state.copyWith(isBroadcastingPayjoinOriginalTx: true, err: null));
      final updatedPayjoin = await _broadcastOriginalTransactionUsecase.execute(
        payjoin,
      );
      emit(
        state.copyWith(
          transaction: state.transaction?.copyWith(payjoin: updatedPayjoin),
        ),
      );
    } catch (e) {
      emit(state.copyWith(err: e));
    } finally {
      emit(state.copyWith(isBroadcastingPayjoinOriginalTx: false));
    }
  }

  /// Deletes a transaction note. Returns the [Result] so the caller can give
  /// the user feedback on failure; on success the note is dropped from state.
  Future<Result<Null, LabelFailure>> deleteTransactionNote(Label note) async {
    final walletTransaction = state.walletTransaction;
    if (walletTransaction == null) return const Ok(null);

    final result = await _labelsFacade.trash(note.id);
    if (result case Ok()) {
      final updatedLabels = [...?state.transaction?.walletTransaction?.labels];
      updatedLabels.remove(note);

      final updatedWalletTransaction = state.transaction?.walletTransaction
          ?.copyWith(labels: updatedLabels);
      emit(
        state.copyWith(
          transaction: state.transaction?.copyWith(
            walletTransaction: updatedWalletTransaction,
          ),
        ),
      );
    }
    // On Err the note is kept in state; the caller surfaces the failure.
    return result;
  }

  Future<void> processSwap(Swap swap) async {
    emit(state.copyWith(retryingSwap: true));
    await _processSwapUsecase.execute(swap);
    emit(state.copyWith(retryingSwap: false));
  }

  Future<Set<String>> fetchDistinctLabels() async {
    try {
      return await _labelsFacade.fetchDistinctLabels();
    } catch (e) {
      log.warning('Failed to fetch distinct labels: $e');
      emit(state.copyWith(err: e));
      return {};
    }
  }
}
