import 'package:bb_mobile/core/wallet/domain/usecases/check_any_wallet_syncing_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_transactions_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/transactions/bloc/transactions_bloc.dart';
import 'package:bb_mobile/locator.dart';

class TransactionsLocator {
  static void setup() {
    // Bloc
    locator.registerFactory<TransactionsCubit>(
      () => TransactionsCubit(
        getWalletTransactionsUsecase: locator<GetWalletTransactionsUsecase>(),
        watchStartedWalletSyncsUsecase:
            locator<WatchStartedWalletSyncsUsecase>(),
        watchFinishedWalletSyncsUsecase:
            locator<WatchFinishedWalletSyncsUsecase>(),
        checkAnyWalletSyncingUsecase: locator<CheckAnyWalletSyncingUsecase>(),
      ),
    );
  }
}
