import 'package:bb_mobile/core/labels/domain/create_label_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/get_payjoin_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_syncing_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_transactions_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/transactions/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:bb_mobile/features/transactions/blocs/transactions_cubit.dart';
import 'package:bb_mobile/locator.dart';

class TransactionsLocator {
  static void setup() {
    // Bloc
    locator.registerFactoryParam<TransactionsCubit, String?, void>(
      (walletId, _) => TransactionsCubit(
        walletId: walletId,
        getWalletTransactionsUsecase: locator<GetWalletTransactionsUsecase>(),
        watchStartedWalletSyncsUsecase:
            locator<WatchStartedWalletSyncsUsecase>(),
        watchFinishedWalletSyncsUsecase:
            locator<WatchFinishedWalletSyncsUsecase>(),
        checkWalletSyncingUsecase: locator<CheckWalletSyncingUsecase>(),
      ),
    );
    locator.registerFactory<TransactionDetailsCubit>(
      () => TransactionDetailsCubit(
        getWalletUsecase: locator<GetWalletUsecase>(),
        getSwapUsecase: locator<GetSwapUsecase>(),
        watchSwapUsecase: locator<WatchSwapUsecase>(),
        watchPayjoinUsecase: locator<WatchPayjoinUsecase>(),
        getPayjoinByIdUsecase: locator<GetPayjoinByIdUsecase>(),
        createLabelUsecase: locator<CreateLabelUsecase>(),
      ),
    );
  }
}
