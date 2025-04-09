import 'package:bb_mobile/core/transaction/domain/entities/transaction.dart';
import 'package:bb_mobile/core/transaction/domain/usecases/get_transactions_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/transactions/bloc/transactions_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TransactionsCubit extends Cubit<TransactionsState> {
  TransactionsCubit({
    required GetTransactionsUsecase getTransactionsUsecase,
    required GetWalletsUsecase getWalletsUsecase,
  })  : _getTransactionsUsecase = getTransactionsUsecase,
        _getWalletsUsecase = getWalletsUsecase,
        super(const TransactionsState()) {
    loadTxs();
  }

  final GetTransactionsUsecase _getTransactionsUsecase;
  final GetWalletsUsecase _getWalletsUsecase;

  Future<void> loadTxs() async {
    try {
      emit(state.copyWith(loadingTxs: true, err: null));
      final wallets = await _getWalletsUsecase.execute(
        onlyDefaults: true,
        sync: true,
      );

      final List<Transaction> allTransactions = [];

      for (final wallet in wallets) {
        final walletTransactions =
            await _getTransactionsUsecase.execute(walletId: wallet.id);
        allTransactions.addAll(walletTransactions);
      }

      emit(state.copyWith(loadingTxs: false, transactions: allTransactions));
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
