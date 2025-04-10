import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet_transaction/domain/usecases/get_wallet_transactions_usecase.dart';
import 'package:bb_mobile/features/transactions/bloc/transactions_bloc.dart';
import 'package:bb_mobile/locator.dart';

class TransactionsLocator {
  static void setup() {
    // Bloc
    locator.registerFactory<TransactionsCubit>(
      () => TransactionsCubit(
        getWalletTransactionsUsecase: locator<GetWalletTransactionsUsecase>(),
        getWalletsUsecase: locator<GetWalletsUsecase>(),
      ),
    );
  }
}
