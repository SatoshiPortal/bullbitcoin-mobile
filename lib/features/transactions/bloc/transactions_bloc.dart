import 'package:bb_mobile/core/wallet_transaction/domain/usecases/get_wallet_transactions_usecase.dart';
import 'package:bb_mobile/features/transactions/bloc/transactions_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TransactionsCubit extends Cubit<TransactionsState> {
  TransactionsCubit({
    required GetWalletTransactionsUsecase getWalletTransactionsUsecase,
  })  : _getWalletTransactionsUsecase = getWalletTransactionsUsecase,
        super(const TransactionsState()) {
    loadTxs();
  }

  final GetWalletTransactionsUsecase _getWalletTransactionsUsecase;

  Future<void> loadTxs() async {
    try {
      // First get the transactions before syncing to avoid showing a blank page
      //  while syncing
      final transactionsBeforeSyncing =
          await _getWalletTransactionsUsecase.execute();

      emit(
        state.copyWith(
          transactions: transactionsBeforeSyncing,
          loadingTxs: true,
          err: null,
        ),
      );

      // Now sync and get the transactions again
      final syncedTransactions = await _getWalletTransactionsUsecase.execute(
        sync: true,
      );

      emit(state.copyWith(loadingTxs: false, transactions: syncedTransactions));
    } catch (e) {
      emit(state.copyWith(loadingTxs: false, err: e));
    }
  }
}

/***
 * 
 * 
 * #0      WalletManagerServiceImpl.getTransactions (package:bb_mobile/core/wallet/data/services/wallet_manager_service_impl.dart:634:11)
<asynchronous suspension>
#1      GetTransactionsUsecase.execute (package:bb_mobile/core/wallet/domain/usecases/get_wallet_transactions_usecase.dart:14:12)
<asynchronous suspension>
#2      TransactionsCubit.loadTxs (package:bb_mobile/features/transactions/bloc/transactions_bloc.dart:28:21)
<asynchronous suspension>

 */
