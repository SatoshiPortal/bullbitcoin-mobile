import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/labels/domain/create_label_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/broadcast_original_transaction_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_syncing_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_transaction_by_tx_id_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/domain/usecases/get_swap_counterpart_transaction_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/usecases/get_transactions_by_tx_id_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/usecases/get_transactions_usecase.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transactions_cubit.dart';
import 'package:bb_mobile/locator.dart';

class TransactionsLocator {
  static void registerUsecases() {
    locator.registerFactory<GetTransactionsUsecase>(
      () => GetTransactionsUsecase(
        settingsRepository: locator<SettingsRepository>(),
        walletTransactionRepository: locator<WalletTransactionRepository>(),
        mainnetSwapRepository: locator<SwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        testnetSwapRepository: locator<SwapRepository>(
          instanceName:
              LocatorInstanceNameConstants
                  .boltzTestnetSwapRepositoryInstanceName,
        ),
        payjoinRepository: locator<PayjoinRepository>(),
        orderRepository: locator<ExchangeOrderRepository>(),
      ),
    );

    locator.registerFactory<GetTransactionsByTxIdUsecase>(
      () => GetTransactionsByTxIdUsecase(
        settingsRepository: locator<SettingsRepository>(),
        walletTransactionRepository: locator<WalletTransactionRepository>(),
        mainnetSwapRepository: locator<SwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        testnetSwapRepository: locator<SwapRepository>(
          instanceName:
              LocatorInstanceNameConstants
                  .boltzTestnetSwapRepositoryInstanceName,
        ),
        payjoinRepository: locator<PayjoinRepository>(),
      ),
    );

    locator.registerFactory<GetSwapCounterpartTransactionUsecase>(
      () => GetSwapCounterpartTransactionUsecase(
        settingsRepository: locator<SettingsRepository>(),
        walletTransactionRepository: locator<WalletTransactionRepository>(),
        mainnetSwapRepository: locator<SwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        testnetSwapRepository: locator<SwapRepository>(
          instanceName:
              LocatorInstanceNameConstants
                  .boltzTestnetSwapRepositoryInstanceName,
        ),
        payjoinRepository: locator<PayjoinRepository>(),
      ),
    );
  }

  static void registerBlocs() {
    // Bloc
    locator.registerFactoryParam<TransactionsCubit, String?, void>(
      (walletId, _) => TransactionsCubit(
        walletId: walletId,
        getTransactionsUsecase: locator<GetTransactionsUsecase>(),
        watchStartedWalletSyncsUsecase:
            locator<WatchStartedWalletSyncsUsecase>(),
        watchFinishedWalletSyncsUsecase:
            locator<WatchFinishedWalletSyncsUsecase>(),
        checkWalletSyncingUsecase: locator<CheckWalletSyncingUsecase>(),
      ),
    );
    locator.registerFactoryParam<TransactionDetailsCubit, Transaction, void>(
      (transaction, _) => TransactionDetailsCubit(
        transaction: transaction,
        getWalletUsecase: locator<GetWalletUsecase>(),
        getSwapCounterpartTransactionUsecase:
            locator<GetSwapCounterpartTransactionUsecase>(),
        getTransactionsByTxIdUsecase: locator<GetTransactionsByTxIdUsecase>(),
        watchWalletTransactionByTxIdUsecase:
            locator<WatchWalletTransactionByTxIdUsecase>(),
        watchSwapUsecase: locator<WatchSwapUsecase>(),
        watchPayjoinUsecase: locator<WatchPayjoinUsecase>(),
        createLabelUsecase: locator<CreateLabelUsecase>(),
        broadcastOriginalTransactionUsecase:
            locator<BroadcastOriginalTransactionUsecase>(),
      ),
    );
  }
}
