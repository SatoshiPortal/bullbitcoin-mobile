import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/usecases/get_order_usercase.dart';
import 'package:bb_mobile/core/labels/domain/delete_label_usecase.dart';
import 'package:bb_mobile/core/labels/domain/fetch_distinct_labels_usecase.dart';
import 'package:bb_mobile/core/labels/domain/label.dart';
import 'package:bb_mobile/core/labels/domain/label_transaction_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/broadcast_original_transaction_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/get_payjoin_by_id_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/process_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/note_validator.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_transaction_by_tx_id_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_error.dart';
import 'package:bb_mobile/features/transactions/domain/usecases/get_transactions_by_tx_id_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_details_cubit.freezed.dart';
part 'transaction_details_state.dart';

class TransactionDetailsCubit extends Cubit<TransactionDetailsState> {
  TransactionDetailsCubit({
    required GetWalletUsecase getWalletUsecase,
    required GetTransactionsByTxIdUsecase getTransactionsByTxIdUsecase,
    required WatchWalletTransactionByTxIdUsecase
    watchWalletTransactionByTxIdUsecase,
    required GetSwapUsecase getSwapUsecase,
    required GetPayjoinByIdUsecase getPayjoinByIdUsecase,
    required GetOrderUsecase getOrderUsecase,
    required WatchSwapUsecase watchSwapUsecase,
    required WatchPayjoinUsecase watchPayjoinUsecase,
    required LabelTransactionUsecase labelTransactionUsecase,
    required DeleteLabelUsecase deleteLabelUsecase,
    required BroadcastOriginalTransactionUsecase
    broadcastOriginalTransactionUsecase,
    required ProcessSwapUsecase processSwapUsecase,
    required FetchDistinctLabelsUsecase fetchDistinctLabelsUsecase,
  }) : _getWalletUsecase = getWalletUsecase,
       _getTransactionsByTxIdUsecase = getTransactionsByTxIdUsecase,
       _watchWalletTransactionByTxIdUsecase =
           watchWalletTransactionByTxIdUsecase,
       _getSwapUsecase = getSwapUsecase,
       _getPayjoinByIdUsecase = getPayjoinByIdUsecase,
       _getOrderUsecase = getOrderUsecase,
       _watchSwapUsecase = watchSwapUsecase,
       _watchPayjoinUsecase = watchPayjoinUsecase,
       _labelTransactionUsecase = labelTransactionUsecase,
       _deleteLabelUsecase = deleteLabelUsecase,
       _broadcastOriginalTransactionUsecase =
           broadcastOriginalTransactionUsecase,
       _processSwapUsecase = processSwapUsecase,
       _fetchDistinctLabelsUsecase = fetchDistinctLabelsUsecase,
       super(const TransactionDetailsState());

  final GetWalletUsecase _getWalletUsecase;
  final GetTransactionsByTxIdUsecase _getTransactionsByTxIdUsecase;
  final WatchWalletTransactionByTxIdUsecase
  _watchWalletTransactionByTxIdUsecase;
  final GetSwapUsecase _getSwapUsecase;
  final GetPayjoinByIdUsecase _getPayjoinByIdUsecase;
  final GetOrderUsecase _getOrderUsecase;
  final WatchSwapUsecase _watchSwapUsecase;
  final WatchPayjoinUsecase _watchPayjoinUsecase;
  final LabelTransactionUsecase _labelTransactionUsecase;
  final DeleteLabelUsecase _deleteLabelUsecase;
  final BroadcastOriginalTransactionUsecase
  _broadcastOriginalTransactionUsecase;
  final ProcessSwapUsecase _processSwapUsecase;
  final FetchDistinctLabelsUsecase _fetchDistinctLabelsUsecase;

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
        ),
      );
    } on TransactionNotFoundError catch (e) {
      emit(state.copyWith(notFoundError: e));
    } catch (e) {
      emit(state.copyWith(err: e));
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

  Future<void> onNoteChanged(String note) async {
    final validation = NoteValidator.validate(note);
    if (!validation.isValid) {
      emit(state.copyWith(err: validation.errorMessage, note: note));
    } else {
      emit(state.copyWith(note: note.trim(), err: null));
    }
  }

  Future<void> saveTransactionNote() async {
    // TODO: Permit multiple labels && labels for payjoin txs, so not only wallet txs (for example set on the original tx)
    //  I think the entity should be changed to Transaction instead of WalletTransaction for that

    if (state.walletTransaction == null ||
        state.note == null ||
        state.walletTransaction!.labels.contains(state.note)) {
      return;
    }
    if (state.walletTransaction!.labels.length >= 10) {
      emit(state.copyWith(err: 'You can only have up to 10 labels'));
      return;
    }

    await _labelTransactionUsecase.execute(
      txid: state.walletTransaction!.txId,
      origin: state.walletTransaction!.walletId,
      label: state.note!,
    );

    final updatedWalletransaction = state.transaction?.walletTransaction
        ?.copyWith(
          labels: [
            ...?state.transaction?.walletTransaction?.labels,
            state.note!,
          ],
        );
    emit(
      state.copyWith(
        note: null,
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
      emit(state.copyWith(isBroadcastingPayjoinOriginalTx: false, note: null));
    }
  }

  Future<void> deleteTransactionNote(String note) async {
    final walletTransaction = state.walletTransaction;
    if (walletTransaction == null) return;

    try {
      final transactionLabel = Label.tx(
        transactionId: walletTransaction.txId,
        label: note,
        origin: walletTransaction.walletId,
      );
      await _deleteLabelUsecase.execute(transactionLabel);

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
    } catch (e) {
      emit(state.copyWith(err: e));
    }
  }

  Future<void> editTransactionNote(String oldNote, String newNote) async {
    final walletTransaction = state.walletTransaction;
    if (walletTransaction == null) return;

    try {
      final oldLabel = Label.tx(
        transactionId: walletTransaction.txId,
        label: oldNote,
        origin: walletTransaction.walletId,
      );
      await _deleteLabelUsecase.execute(oldLabel);

      await _labelTransactionUsecase.execute(
        txid: walletTransaction.txId,
        origin: walletTransaction.walletId,
        label: newNote,
      );

      final updatedLabels = [...?state.transaction?.walletTransaction?.labels];
      updatedLabels.remove(oldNote);
      updatedLabels.add(newNote);

      final updatedWalletTransaction = state.transaction?.walletTransaction
          ?.copyWith(labels: updatedLabels);
      emit(
        state.copyWith(
          transaction: state.transaction?.copyWith(
            walletTransaction: updatedWalletTransaction,
          ),
        ),
      );
    } catch (e) {
      emit(state.copyWith(err: e));
    }
  }

  Future<void> processSwap(Swap swap) async {
    emit(state.copyWith(retryingSwap: true));
    await _processSwapUsecase.execute(swap);
    emit(state.copyWith(retryingSwap: false));
  }

  Future<List<String>> fetchDistinctLabels() async {
    try {
      return await _fetchDistinctLabelsUsecase.execute();
    } catch (e) {
      log.warning('Failed to fetch distinct labels: $e');
      emit(state.copyWith(err: e));
      return [];
    }
  }
}
