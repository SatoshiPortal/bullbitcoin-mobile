import 'dart:async';

import 'package:bb_mobile/core/labels/domain/create_label_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/broadcast_original_transaction_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/get_payjoin_by_id_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_transaction_by_tx_id_usecase.dart';
import 'package:bb_mobile/features/transactions/presentation/view_models/transaction_view_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_details_cubit.freezed.dart';
part 'transaction_details_state.dart';

class TransactionDetailsCubit extends Cubit<TransactionDetailsState> {
  TransactionDetailsCubit({
    required GetWalletUsecase getWalletUsecase,
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
       _watchWalletTransactionByTxIdUsecase =
           watchWalletTransactionByTxIdUsecase,
       _getSwapUsecase = getSwapUsecase,
       _watchSwapUsecase = watchSwapUsecase,
       _getPayjoinByIdUsecase = getPayjoinByIdUsecase,
       _watchPayjoinUsecase = watchPayjoinUsecase,
       _createLabelUsecase = createLabelUsecase,
       _broadcastOriginalTransactionUsecase =
           broadcastOriginalTransactionUsecase,
       super(const TransactionDetailsState());

  final GetWalletUsecase _getWalletUsecase;
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
  }

  Future<void> saveTransactionNote(String note) async {
    // TODO: Permit multiple labels && labels from payjoin txs (for example set on the original tx)
    final transaction = state.transaction;
    if (transaction == null || transaction.walletTransaction == null) return;

    await _createLabelUsecase.execute<WalletTransaction>(
      origin: transaction.wallet!.origin,
      entity: transaction.walletTransaction!,
      label: note,
    );

    final updatedTransaction = transaction.copyWith(
      walletTransaction: transaction.walletTransaction?.copyWith(
        labels: [...transaction.walletTransaction!.labels, note],
      ),
    );
    emit(state.copyWith(transaction: updatedTransaction));
  }

  Future<void> broadcastPayjoinOriginalTx() async {
    try {
      final payjoin = state.transaction?.payjoin;
      if (payjoin == null) return;
      emit(state.copyWith(isBroadcastingPayjoinOriginalTx: true));
      final updatedPayjoin = await _broadcastOriginalTransactionUsecase.execute(
        payjoin,
      );
      emit(
        state.copyWith(
          transaction: state.transaction?.copyWith(payjoin: updatedPayjoin),
          err: null,
          isBroadcastingPayjoinOriginalTx: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(err: e, isBroadcastingPayjoinOriginalTx: false));
    }
  }
}
