import 'package:bb_mobile/core/utils/bitcoin_tx.dart' as btc_utils;
import 'package:bb_mobile/features/broadcast_signed_tx/application/build_reviewable_transaction_usecase.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/domain_errors.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/transaction_review_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Drives the transaction-review screen for the broadcast flow.
///
/// Resolves a parsed [btc_utils.BitcoinTx] into a [ReviewableTransaction]
/// (input values fetched via the transaction port) and surfaces failures
/// as [TransactionReviewError] for the view to render.
class TransactionReviewCubit extends Cubit<TransactionReviewState> {
  final BuildReviewableTransactionUsecase _buildReviewableTransactionUsecase;

  TransactionReviewCubit({
    required BuildReviewableTransactionUsecase
    buildReviewableTransactionUsecase,
  }) : _buildReviewableTransactionUsecase = buildReviewableTransactionUsecase,
       super(const TransactionReviewState.initial());

  Future<void> loadFromBitcoinTx(
    btc_utils.BitcoinTx bitcoinTx, {
    required bool isTestnet,
  }) async {
    if (state is TransactionReviewLoading) return;
    emit(const TransactionReviewState.loading());
    try {
      final transaction = await _buildReviewableTransactionUsecase.execute(
        bitcoinTx,
        isTestnet: isTestnet,
      );
      emit(TransactionReviewState.loaded(transaction: transaction));
    } on TransactionReviewError catch (e) {
      emit(TransactionReviewState.error(error: e));
    } catch (e) {
      emit(
        TransactionReviewState.error(
          error: TransactionReviewError.unexpected(e.toString()),
        ),
      );
    }
  }
}
