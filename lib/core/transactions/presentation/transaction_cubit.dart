import 'package:bb_mobile/core/transactions/application/build_transaction_usecase.dart';
import 'package:bb_mobile/core/transactions/domain/error/transaction_error.dart';
import 'package:bb_mobile/core/transactions/presentation/transaction_state.dart';
import 'package:bb_mobile/core/utils/bitcoin_tx.dart' as btc_utils;
import 'package:flutter_bloc/flutter_bloc.dart';

/// Cubit managing the state of a transaction being reviewed.
///
/// Takes a raw parsed [btc_utils.BitcoinTx] (from PSBT/HEX) and resolves
/// it to a [TransactionEntity] via [BuildTransactionUsecase], which handles
/// both domain mapping and asynchronous input-value resolution via Electrum.
class TransactionCubit extends Cubit<TransactionState> {
  final BuildTransactionUsecase _buildTransactionUsecase;

  TransactionCubit({required BuildTransactionUsecase buildTransactionUsecase})
    : _buildTransactionUsecase = buildTransactionUsecase,
      super(const TransactionState.initial());

  Future<void> loadFromBitcoinTx(
    btc_utils.BitcoinTx bitcoinTx, {
    required bool isTestnet,
  }) async {
    if (state is TransactionLoading) return;
    emit(const TransactionState.loading());
    try {
      final entity = await _buildTransactionUsecase.executeFromBitcoinTx(
        bitcoinTx,
        isTestnet: isTestnet,
      );
      emit(TransactionState.loaded(entity: entity));
    } on TransactionError catch (e) {
      emit(TransactionState.error(error: e));
    } catch (e) {
      emit(
        TransactionState.error(
          error: TransactionError.unexpected(e.toString()),
        ),
      );
    }
  }
}
