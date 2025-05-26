import 'package:bb_mobile/core/labels/domain/create_label_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/broadcast_original_transaction_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/get_payjoin_by_id_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/get_payjoins_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swaps_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_syncing_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_transactions_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_transaction_by_tx_id_usecase.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transactions_cubit.dart';
import 'package:bb_mobile/locator.dart';

class TransactionsLocator {
  static void setup() {
    // Bloc
    locator.registerFactoryParam<TransactionsCubit, String?, void>(
      (walletId, _) => TransactionsCubit(
        walletId: walletId,
        getWalletTransactionsUsecase: locator<GetWalletTransactionsUsecase>(),
        getPayjoinsUsecase: locator<GetPayjoinsUsecase>(),
        getSwapsUsecase: locator<GetSwapsUsecase>(),
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
        watchWalletTransactionByTxIdUsecase:
            locator<WatchWalletTransactionByTxIdUsecase>(),
        getSwapUsecase: locator<GetSwapUsecase>(),
        watchSwapUsecase: locator<WatchSwapUsecase>(),
        watchPayjoinUsecase: locator<WatchPayjoinUsecase>(),
        getPayjoinByIdUsecase: locator<GetPayjoinByIdUsecase>(),
        createLabelUsecase: locator<CreateLabelUsecase>(),
        broadcastOriginalTransactionUsecase:
            locator<BroadcastOriginalTransactionUsecase>(),
      ),
    );
  }
}
