import 'package:bb_mobile/core/transactions/adapters/transaction_mapper.dart';
import 'package:bb_mobile/core/utils/bitcoin_tx.dart' as btc_utils;
import 'package:bb_mobile/features/broadcast_signed_tx/application/build_reviewable_transaction_usecase.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/domain_errors.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/transaction_review_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Drives the transaction-review screen for the broadcast flow.
///
/// Translates the raw [btc_utils.BitcoinTx] (parsed from PSBT/HEX at the
/// scan/paste boundary) into a domain [Transaction] before handing it to
/// the usecase — the application layer stays free of foreign BDK types.
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
      final tx = TransactionMapper.fromBitcoinTx(
        bitcoinTx,
        isTestnet: isTestnet,
      );
      final reviewable = await _buildReviewableTransactionUsecase.execute(tx);
      emit(TransactionReviewState.loaded(transaction: reviewable));
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
