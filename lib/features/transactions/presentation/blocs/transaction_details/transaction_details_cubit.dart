import 'dart:async';

import 'package:bb_mobile/core/labels/domain/create_label_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/broadcast_original_transaction_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/get_payjoin_by_id_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_transaction_by_tx_id_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/domain/usecases/get_swap_counterpart_transaction_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/usecases/get_transactions_by_tx_id_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_details_cubit.freezed.dart';
part 'transaction_details_state.dart';

class TransactionDetailsCubit extends Cubit<TransactionDetailsState> {
  TransactionDetailsCubit({
    required Transaction transaction,
    required GetWalletUsecase getWalletUsecase,
    required GetSwapCounterpartTransactionUsecase
    getSwapCounterpartTransactionUsecase,
    required GetTransactionsByTxIdUsecase getTransactionsByTxIdUsecase,
    required WatchWalletTransactionByTxIdUsecase
    watchWalletTransactionByTxIdUsecase,
    required GetSwapUsecase getSwapUsecase,
    required WatchSwapUsecase watchSwapUsecase,
    required GetPayjoinByIdUsecase getPayjoinByIdUsecase,
    required WatchPayjoinUsecase watchPayjoinUsecase,
    required CreateLabelUsecase createLabelUsecase,
    required BroadcastOriginalTransactionUsecase
    broadcastOriginalTransactionUsecase,
  }) : _getWalletUsecase = getWalletUsecase,
       _getSwapCounterpartTransactionUsecase =
           getSwapCounterpartTransactionUsecase,
       _getTransactionsByTxIdUsecase = getTransactionsByTxIdUsecase,
       _watchWalletTransactionByTxIdUsecase =
           watchWalletTransactionByTxIdUsecase,
       _getSwapUsecase = getSwapUsecase,
       _watchSwapUsecase = watchSwapUsecase,
       _getPayjoinByIdUsecase = getPayjoinByIdUsecase,
       _watchPayjoinUsecase = watchPayjoinUsecase,
       _createLabelUsecase = createLabelUsecase,
       _broadcastOriginalTransactionUsecase =
           broadcastOriginalTransactionUsecase,
       super(TransactionDetailsState(transaction: transaction));

  final GetWalletUsecase _getWalletUsecase;
  final GetSwapCounterpartTransactionUsecase
  _getSwapCounterpartTransactionUsecase;
  final GetTransactionsByTxIdUsecase _getTransactionsByTxIdUsecase;

  final WatchWalletTransactionByTxIdUsecase
  _watchWalletTransactionByTxIdUsecase;
  final GetSwapUsecase _getSwapUsecase;
  final WatchSwapUsecase _watchSwapUsecase;
  final GetPayjoinByIdUsecase _getPayjoinByIdUsecase;
  final WatchPayjoinUsecase _watchPayjoinUsecase;
  final CreateLabelUsecase _createLabelUsecase;
  final BroadcastOriginalTransactionUsecase
  _broadcastOriginalTransactionUsecase;

  StreamSubscription? _payjoinSubscription;
  StreamSubscription? _swapSubscription;

  @override
  Future<void> close() async {
    await (
      _payjoinSubscription?.cancel() ?? Future.value(),
      _swapSubscription?.cancel() ?? Future.value(),
    ).wait;
    return super.close();
  }

  Future<void> load() async {
    try {
      final tx = state.transaction;
      final walletId = tx.walletId;
      final wallet = await _getWalletUsecase.execute(walletId);

      if (wallet == null) {
        throw Exception('Wallet not found for id: $walletId');
      }

      Wallet? counterpartWallet;
      Transaction? swapCounterpartTransaction;
      if (tx.isChainSwap) {
        // Get the counterpart transaction and wallet for chain swaps.
        final swap = tx.swap! as ChainSwap;
        final counterpartWalletId =
            walletId == swap.sendWalletId
                ? swap.receiveWalletId
                : swap.sendWalletId;
        if (counterpartWalletId != null) {
          (counterpartWallet, swapCounterpartTransaction) =
              await (
                _getWalletUsecase.execute(counterpartWalletId),
                _getSwapCounterpartTransactionUsecase.execute(tx),
              ).wait;
        }
      } else {
        // Check if the transaction is between internal wallets. This is the case
        // if more than one transaction is returned for the same txId.
        final txId = tx.txId;
        if (txId != null) {
          final transactions = await _getTransactionsByTxIdUsecase.execute(
            txId,
          );
          // Retain only transactions that are not the same wallet and
          // have the opposite isIncoming value.
          // This is to find the counterpart wallet for the transaction.
          transactions.retainWhere(
            (t) => t.walletId != tx.walletId && t.isIncoming != tx.isIncoming,
          );
          if (transactions.isNotEmpty) {
            // If a transaction is found, get the wallet for it.
            counterpartWallet = await _getWalletUsecase.execute(
              transactions.first.walletId,
            );
          }
        }
      }

      emit(
        state.copyWith(
          isLoading: false,
          wallet: wallet,
          counterpartWallet: counterpartWallet,
          swapCounterpartTransaction: swapCounterpartTransaction,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, err: e));
    }
  }

  /*
  Future<void> monitorTransaction(TransactionViewModel tx) async {
    try {
      emit(state.copyWith(transaction: tx));

      // Check if the transaction was a payjoin and if so, start monitoring it
      if (tx.payjoin != null) {
        final payjoinId = tx.payjoin!.id;
        final payjoin = await _getPayjoinByIdUsecase.execute(payjoinId);
        _payjoinSubscription = _watchPayjoinUsecase
            .execute(ids: [payjoinId])
            .listen(
              (payjoin) => emit(
                state.copyWith(
                  transaction: state.transaction?.copyWith(payjoin: payjoin),
                ),
              ),
            );

        emit(
          state.copyWith(
            transaction: state.transaction?.copyWith(payjoin: payjoin),
          ),
        );
      }

      if (tx.swap != null) {
        // Get swap by id
        final swapId = tx.swap!.id;
        final swap = await _getSwapUsecase.execute(
          swapId,
          isTestnet: tx.isTestnet,
        );
        // Watch swap by id so the UI can update if the state changes
        _swapSubscription = _watchSwapUsecase
            .execute(swapId)
            .listen(
              (swap) => emit(
                state.copyWith(
                  transaction: state.transaction?.copyWith(swap: swap),
                ),
              ),
            );
        emit(
          state.copyWith(transaction: state.transaction?.copyWith(swap: swap)),
        );
      }
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(err: e));
      }
    }
  }*/

  Future<void> saveTransactionNote(String note) async {
    // TODO: Permit multiple labels && labels for payjoin txs, so not only wallet txs (for example set on the original tx)
    //  I think the entity should be changed to Transaction instead of WalletTransaction for that
    final walletTransaction = state.walletTransaction;
    if (walletTransaction == null) return;

    await _createLabelUsecase.execute<WalletTransaction>(
      origin: state.wallet!.origin,
      entity: walletTransaction,
      label: note,
    );

    final updatedWalletransaction = state.transaction.walletTransaction
        ?.copyWith(
          labels: [...?state.transaction.walletTransaction?.labels, note],
        );
    emit(
      state.copyWith(
        transaction: state.transaction.copyWith(
          walletTransaction: updatedWalletransaction,
        ),
      ),
    );
  }

  Future<void> broadcastPayjoinOriginalTx() async {
    try {
      final payjoin = state.payjoin;
      if (payjoin == null) return;
      emit(state.copyWith(isBroadcastingPayjoinOriginalTx: true));
      final updatedPayjoin = await _broadcastOriginalTransactionUsecase.execute(
        payjoin,
      );
      emit(
        state.copyWith(
          transaction: state.transaction.copyWith(payjoin: updatedPayjoin),
          err: null,
          isBroadcastingPayjoinOriginalTx: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(err: e, isBroadcastingPayjoinOriginalTx: false));
    }
  }
}
