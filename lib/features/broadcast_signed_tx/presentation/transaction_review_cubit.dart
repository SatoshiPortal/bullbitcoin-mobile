import 'package:bb_mobile/core/transactions/adapters/transaction_mapper.dart';
import 'package:bb_mobile/core/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/core/utils/bitcoin_tx.dart' as btc_utils;
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/application/build_reviewable_transaction_usecase.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/transaction_review_failure.dart';
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
    required this._buildReviewableTransactionUsecase,
  }) : super(const TransactionReviewState.initial());

  Future<void> loadFromBitcoinTx(
    btc_utils.BitcoinTx bitcoinTx, {
    required bool isTestnet,
  }) async {
    if (state is TransactionReviewLoading) return;
    emit(const TransactionReviewState.loading());

    // The cubit owns the foreign BDK -> domain mapping, so it is the boundary
    // for that one call: a defensive catch keeps the raw reason in the logs
    // (Sentry) and surfaces a sanitized failure.
    final Transaction tx;
    try {
      tx = TransactionMapper.fromBitcoinTx(bitcoinTx, isTestnet: isTestnet);
    } catch (e, st) {
      log.severe(
        message: 'Unexpected failure mapping transaction for review',
        error: e,
        trace: st,
      );
      emit(
        TransactionReviewState.error(
          failure: TransactionReviewUnexpectedFailure(e.toString()),
        ),
      );
      return;
    }

    switch (await _buildReviewableTransactionUsecase.execute(tx)) {
      case Ok(:final value):
        emit(TransactionReviewState.loaded(transaction: value));
      case Err(:final failure):
        emit(TransactionReviewState.error(failure: failure));
    }
  }
}
