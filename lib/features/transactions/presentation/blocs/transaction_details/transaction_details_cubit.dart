import 'dart:async';

import 'package:bb_mobile/core/labels/domain/create_label_usecase.dart';
import 'package:bb_mobile/core/labels/domain/delete_label_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/broadcast_original_transaction_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/process_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/utils/note_validator.dart';
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
    required WatchSwapUsecase watchSwapUsecase,
    required WatchPayjoinUsecase watchPayjoinUsecase,
    required CreateLabelUsecase createLabelUsecase,
    required DeleteLabelUsecase deleteLabelUsecase,
    required BroadcastOriginalTransactionUsecase
    broadcastOriginalTransactionUsecase,
    required ProcessSwapUsecase processSwapUsecase,
  }) : _getWalletUsecase = getWalletUsecase,
       _getSwapCounterpartTransactionUsecase =
           getSwapCounterpartTransactionUsecase,
       _getTransactionsByTxIdUsecase = getTransactionsByTxIdUsecase,
       _watchWalletTransactionByTxIdUsecase =
           watchWalletTransactionByTxIdUsecase,
       _watchSwapUsecase = watchSwapUsecase,
       _watchPayjoinUsecase = watchPayjoinUsecase,
       _createLabelUsecase = createLabelUsecase,
       _deleteLabelUsecase = deleteLabelUsecase,
       _broadcastOriginalTransactionUsecase =
           broadcastOriginalTransactionUsecase,
       _processSwapUsecase = processSwapUsecase,
       _walletTransactionSubscriptions = {},
       super(TransactionDetailsState(transaction: transaction));

  final GetWalletUsecase _getWalletUsecase;
  final GetSwapCounterpartTransactionUsecase
  _getSwapCounterpartTransactionUsecase;
  final GetTransactionsByTxIdUsecase _getTransactionsByTxIdUsecase;

  final WatchWalletTransactionByTxIdUsecase
  _watchWalletTransactionByTxIdUsecase;
  final WatchSwapUsecase _watchSwapUsecase;
  final WatchPayjoinUsecase _watchPayjoinUsecase;
  final CreateLabelUsecase _createLabelUsecase;
  final DeleteLabelUsecase _deleteLabelUsecase;
  final BroadcastOriginalTransactionUsecase
  _broadcastOriginalTransactionUsecase;
  final ProcessSwapUsecase _processSwapUsecase;

  final Map<String, StreamSubscription> _walletTransactionSubscriptions;
  StreamSubscription? _payjoinSubscription;
  StreamSubscription? _swapSubscription;

  @override
  Future<void> close() async {
    await Future.wait([
      ..._walletTransactionSubscriptions.values.map(
        (subscription) async => await subscription.cancel(),
      ),
      _payjoinSubscription?.cancel() ?? Future.value(),
      _swapSubscription?.cancel() ?? Future.value(),
    ]);
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

      // Now start monitoring the wallet transaction for updates.
      if (tx.txId != null) {
        _startMonitoringWalletTransaction(tx.txId!, walletId: wallet.id);
      }
      // If the transaction is a payjoin or swap, start monitoring them as well.
      if (tx.isPayjoin) {
        final payjoinId = tx.payjoin!.id;
        _startMonitoringPayjoin(payjoinId, walletId: wallet.id);
      }
      if (tx.isSwap) {
        final swapId = tx.swap!.id;
        _startMonitoringSwap(swapId, walletId: wallet.id);
      }
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(isLoading: false, err: e));
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

  Future<void> saveTransactionNote(String note) async {
    // TODO: Permit multiple labels && labels for payjoin txs, so not only wallet txs (for example set on the original tx)
    //  I think the entity should be changed to Transaction instead of WalletTransaction for that

    if (state.walletTransaction == null || state.note == null) return;

    await _createLabelUsecase.execute<WalletTransaction>(
      origin: state.wallet!.origin,
      entity: state.walletTransaction!,
      label: state.note!,
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

  void _startMonitoringWalletTransaction(
    String txId, {
    required String walletId,
  }) {
    _walletTransactionSubscriptions.putIfAbsent(
      txId,
      () => _watchWalletTransactionByTxIdUsecase
          .execute(txId: txId, walletId: walletId)
          .listen((walletTransaction) {
            emit(
              state.copyWith(
                transaction: state.transaction.copyWith(
                  walletTransaction: walletTransaction,
                ),
              ),
            );
          }),
    );
  }

  void _startMonitoringPayjoin(String payjoinId, {required String walletId}) {
    _payjoinSubscription = _watchPayjoinUsecase
        .execute(ids: [payjoinId])
        .listen((payjoin) {
          emit(
            state.copyWith(
              transaction: state.transaction.copyWith(payjoin: payjoin),
            ),
          );
          if (payjoin.txId != null) {
            _startMonitoringWalletTransaction(
              payjoin.txId!,
              walletId: walletId,
            );
          }
          if (payjoin.originalTxId != null) {
            _startMonitoringWalletTransaction(
              payjoin.originalTxId!,
              walletId: walletId,
            );
          }
        });
  }

  void _startMonitoringSwap(String swapId, {required String walletId}) {
    _swapSubscription = _watchSwapUsecase.execute(swapId).listen((swap) async {
      emit(state.copyWith(transaction: state.transaction.copyWith(swap: swap)));
      if (swap.txId != null) {
        if (swap.walletId == walletId) {
          _startMonitoringWalletTransaction(swap.txId!, walletId: walletId);
        } else if (swap.receiveTxId != null) {
          // If the current wallet is not the initiator of the swap, we watch
          // the counterpart transaction instead, which is the receive transaction
          // currently.
          _startMonitoringWalletTransaction(
            swap.receiveTxId!,
            walletId: swap.walletId,
          );
        }
      }
      // If the swap is a chain swap, we also need to see when the counterpart
      // transaction is available, so we can update the state accordingly.
      if (swap.isChainSwap) {
        final counterpartTransaction =
            await _getSwapCounterpartTransactionUsecase.execute(
              state.transaction,
            );
        emit(
          state.copyWith(swapCounterpartTransaction: counterpartTransaction),
        );
      }
    });
  }

  Future<void> deleteTransactionNote(String note) async {
    final walletTransaction = state.walletTransaction;
    if (walletTransaction == null) return;

    try {
      await _deleteLabelUsecase.execute<WalletTransaction>(
        entity: walletTransaction,
        label: note,
      );

      final updatedLabels = [...?state.transaction.walletTransaction?.labels];
      updatedLabels.remove(note);

      final updatedWalletTransaction = state.transaction.walletTransaction
          ?.copyWith(labels: updatedLabels);
      emit(
        state.copyWith(
          transaction: state.transaction.copyWith(
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
      await _deleteLabelUsecase.execute<WalletTransaction>(
        entity: walletTransaction,
        label: oldNote,
      );

      await _createLabelUsecase.execute<WalletTransaction>(
        origin: state.wallet!.origin,
        entity: walletTransaction,
        label: newNote,
      );

      final updatedLabels = [...?state.transaction.walletTransaction?.labels];
      updatedLabels.remove(oldNote);
      updatedLabels.add(newNote);

      final updatedWalletTransaction = state.transaction.walletTransaction
          ?.copyWith(labels: updatedLabels);
      emit(
        state.copyWith(
          transaction: state.transaction.copyWith(
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
}
