import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_order_usercase.dart';
import 'package:bb_mobile/core/labels/domain/delete_label_usecase.dart';
import 'package:bb_mobile/core/labels/domain/label_wallet_transaction_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/broadcast_original_transaction_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/get_payjoin_by_id_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/process_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_transaction_by_tx_id_usecase.dart';
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
        mainnetBoltzSwapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        testnetBoltzSwapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants
                  .boltzTestnetSwapRepositoryInstanceName,
        ),
        payjoinRepository: locator<PayjoinRepository>(),
        mainnetOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'mainnetExchangeOrderRepository',
        ),
        testnetOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'testnetExchangeOrderRepository',
        ),
      ),
    );

    locator.registerFactory<GetTransactionsByTxIdUsecase>(
      () => GetTransactionsByTxIdUsecase(
        settingsRepository: locator<SettingsRepository>(),
        walletTransactionRepository: locator<WalletTransactionRepository>(),
        mainnetBoltzSwapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        testnetBoltzSwapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants
                  .boltzTestnetSwapRepositoryInstanceName,
        ),
        payjoinRepository: locator<PayjoinRepository>(),
        mainnetOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'mainnetExchangeOrderRepository',
        ),
        testnetOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'testnetExchangeOrderRepository',
        ),
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
      ),
    );
    locator.registerFactory<TransactionDetailsCubit>(
      () => TransactionDetailsCubit(
        getWalletUsecase: locator<GetWalletUsecase>(),
        getTransactionsByTxIdUsecase: locator<GetTransactionsByTxIdUsecase>(),
        watchWalletTransactionByTxIdUsecase:
            locator<WatchWalletTransactionByTxIdUsecase>(),
        getSwapUsecase: locator<GetSwapUsecase>(),
        getPayjoinByIdUsecase: locator<GetPayjoinByIdUsecase>(),
        getOrderUsecase: locator<GetOrderUsecase>(),
        watchSwapUsecase: locator<WatchSwapUsecase>(),
        watchPayjoinUsecase: locator<WatchPayjoinUsecase>(),
        labelWalletTransactionUsecase: locator<LabelWalletTransactionUsecase>(),
        deleteLabelUsecase: locator<DeleteLabelUsecase>(),
        broadcastOriginalTransactionUsecase:
            locator<BroadcastOriginalTransactionUsecase>(),
        processSwapUsecase: locator<ProcessSwapUsecase>(),
      ),
    );
  }
}
