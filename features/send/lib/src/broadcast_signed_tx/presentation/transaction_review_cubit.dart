import 'package:sync/sync.dart' show BitcoinTx;
import 'package:primitives/primitives.dart';
import 'package:send/src/broadcast_signed_tx/application/build_reviewable_transaction_usecase.dart';
import 'package:send/src/broadcast_signed_tx/presentation/transaction_review_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TransactionReviewCubit extends Cubit<TransactionReviewState> {
  final BuildReviewableTransactionUsecase _buildReviewableTransactionUsecase;

  TransactionReviewCubit({required this._buildReviewableTransactionUsecase})
    : super(const TransactionReviewState.initial());

  Future<void> loadFromBitcoinTx(
    BitcoinTx bitcoinTx, {
    required Future<BitcoinNetwork?> network,
  }) async {
    if (state is TransactionReviewLoading) return;
    emit(const TransactionReviewState.loading());

    switch (await _buildReviewableTransactionUsecase.execute(
      bitcoinTx,
      network: network,
    )) {
      case Ok(:final value):
        emit(TransactionReviewState.loaded(transaction: value));
      case Err(:final failure):
        emit(TransactionReviewState.error(failure: failure));
    }
  }
}
