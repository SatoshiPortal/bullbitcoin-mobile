import 'package:bb_mobile/core/wallet/domain/entity/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_transactions_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/transactions/bloc/transactions_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TransactionsCubit extends Cubit<TransactionsState> {
  TransactionsCubit({
    required GetWalletTransactionsUsecase getWalletTransactionsUsecase,
    required GetWalletsUsecase getWalletsUsecase,
  })  : _getWalletTransactionsUsecase = getWalletTransactionsUsecase,
        _getWalletsUsecase = getWalletsUsecase,
        super(const TransactionsState()) {
    loadTxs();
  }

  final GetWalletTransactionsUsecase _getWalletTransactionsUsecase;
  final GetWalletsUsecase _getWalletsUsecase;

  Future<void> loadTxs() async {
    try {
      emit(state.copyWith(loadingTxs: true, err: null));
      final wallets = await _getWalletsUsecase.execute(
        onlyDefaults: true,
      );
      final List<WalletTransaction> txs = [];
      for (final wallet in wallets) {
        final txs = await _getWalletTransactionsUsecase.execute(wallet.id);
        txs.addAll(txs);
      }
      emit(state.copyWith(loadingTxs: false, transactions: txs));
    } catch (e) {
      emit(state.copyWith(loadingTxs: false, err: e));
    }
  }
}
