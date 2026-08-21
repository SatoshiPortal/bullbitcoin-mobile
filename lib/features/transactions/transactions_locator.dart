import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_order_usercase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/list_all_orders_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_transaction_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_transaction_by_tx_id_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/transactions/adapters/csv_transaction_export_formatter.dart';
import 'package:bb_mobile/features/transactions/adapters/csv_transaction_export_saver.dart';
import 'package:bb_mobile/features/transactions/application/ports/transaction_export_formatter.dart';
import 'package:bb_mobile/features/transactions/application/ports/transaction_export_saver.dart';
import 'package:bb_mobile/features/transactions/application/usecases/export_transactions_csv_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transactions_by_tx_id_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transactions_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/refresh_transaction_labels_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/broadcast_original_transaction_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_payjoin_by_id_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_payjoin_by_tx_id_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/label_exchange_orders_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transaction_order_swaps_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transaction_order_swap_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/watch_transaction_order_swap_usecase.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/transactions/transactions_facade.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/export/export_transactions_cubit.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transactions_cubit.dart';
import 'package:get_it/get_it.dart';
import 'package:bull_payjoin/bull_payjoin.dart';

class TransactionsLocator {
  static void registerUsecases(GetIt locator) {
    locator.registerFactory<GetPayjoinByIdUsecase>(
      () => GetPayjoinByIdUsecase(locator<PayjoinSessions>()),
    );
    locator.registerFactory<GetPayjoinByTxIdUsecase>(
      () => GetPayjoinByTxIdUsecase(locator<PayjoinSessions>()),
    );
    locator.registerFactory<WatchPayjoinUsecase>(
      () => WatchPayjoinUsecase(locator<PayjoinSessions>()),
    );
    locator.registerFactory<BroadcastOriginalTransactionUsecase>(
      () => BroadcastOriginalTransactionUsecase(locator<PayjoinSender>()),
    );
    locator.registerFactory<LabelExchangeOrdersUsecase>(
      () => LabelExchangeOrdersUsecase(
        labelsFacade: locator<LabelsFacade>(),
        listAllOrdersUsecase: locator<ListAllOrdersUsecase>(),
        walletTransactionRepository: locator<WalletTransactionRepository>(),
      ),
    );
    locator.registerFactory<TransactionsFacade>(
      () => TransactionsFacade(
        labelExchangeOrdersUsecase: locator<LabelExchangeOrdersUsecase>(),
      ),
    );

    locator.registerFactory<GetTransactionOrderSwapsUsecase>(
      () => GetTransactionOrderSwapsUsecase(locator<SwapFacade>()),
    );
    locator.registerFactory<GetTransactionOrderSwapUsecase>(
      () => GetTransactionOrderSwapUsecase(locator<SwapFacade>()),
    );
    locator.registerFactory<WatchTransactionOrderSwapUsecase>(
      () => WatchTransactionOrderSwapUsecase(locator<SwapFacade>()),
    );
    locator.registerFactory<GetTransactionsUsecase>(
      () => GetTransactionsUsecase(
        settingsRepository: locator<SettingsRepository>(),
        walletTransactionRepository: locator<WalletTransactionRepository>(),
        boltzSwapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        payjoinSessions: locator<PayjoinSessions>(),
        mainnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'mainnetExchangeOrderRepository',
        ),
        testnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'testnetExchangeOrderRepository',
        ),
        labelExchangeOrdersUsecase: locator<LabelExchangeOrdersUsecase>(),
        getTransactionOrderSwapsUsecase:
            locator<GetTransactionOrderSwapsUsecase>(),
      ),
    );

    locator.registerFactory<RefreshTransactionLabelsUsecase>(
      () => RefreshTransactionLabelsUsecase(
        labelsFacade: locator<LabelsFacade>(),
      ),
    );

    locator.registerFactory<ExportTransactionsCsvUsecase>(
      () => ExportTransactionsCsvUsecase(
        getTransactionsUsecase: locator<GetTransactionsUsecase>(),
        formatter: locator<TransactionExportFormatter>(),
      ),
    );

    locator.registerFactory<GetTransactionsByTxIdUsecase>(
      () => GetTransactionsByTxIdUsecase(
        settingsRepository: locator<SettingsRepository>(),
        walletTransactionRepository: locator<WalletTransactionRepository>(),
        boltzSwapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        payjoinSessions: locator<PayjoinSessions>(),
        mainnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'mainnetExchangeOrderRepository',
        ),
        testnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'testnetExchangeOrderRepository',
        ),
        getTransactionOrderSwapsUsecase:
            locator<GetTransactionOrderSwapsUsecase>(),
      ),
    );
  }

  static void registerAdapters(GetIt locator) {
    locator.registerLazySingleton<TransactionExportFormatter>(
      CsvTransactionExportFormatter.new,
    );

    locator.registerLazySingleton<TransactionExportSaver>(
      CsvTransactionExportSaver.new,
    );
  }

  static void registerBlocs(GetIt locator) {
    // Bloc
    locator.registerFactoryParam<TransactionsCubit, String?, bool?>(
      (walletId, exchangeOnly) => TransactionsCubit(
        walletId: walletId,
        exchangeOnly: exchangeOnly ?? false,
        getTransactionsUsecase: locator<GetTransactionsUsecase>(),
        refreshTransactionLabelsUsecase:
            locator<RefreshTransactionLabelsUsecase>(),
        watchStartedWalletSyncsUsecase:
            locator<WatchStartedWalletSyncsUsecase>(),
        watchFinishedWalletSyncsUsecase:
            locator<WatchFinishedWalletSyncsUsecase>(),
      ),
    );
    locator.registerFactory<ExportTransactionsCubit>(
      () => ExportTransactionsCubit(
        exportTransactionsCsvUsecase: locator<ExportTransactionsCsvUsecase>(),
        saver: locator<TransactionExportSaver>(),
      ),
    );
    locator.registerFactory<TransactionDetailsCubit>(
      () => TransactionDetailsCubit(
        getWalletUsecase: locator<GetWalletUsecase>(),
        getTransactionsByTxIdUsecase: locator<GetTransactionsByTxIdUsecase>(),
        getWalletTransactionUsecase: locator<GetWalletTransactionUsecase>(),
        getTransactionOrderSwapUsecase:
            locator<GetTransactionOrderSwapUsecase>(),
        watchWalletTransactionByTxIdUsecase:
            locator<WatchWalletTransactionByTxIdUsecase>(),
        getSwapUsecase: locator<GetSwapUsecase>(),
        getPayjoinByIdUsecase: locator<GetPayjoinByIdUsecase>(),
        getPayjoinByTxIdUsecase: locator<GetPayjoinByTxIdUsecase>(),
        getOrderUsecase: locator<GetOrderUsecase>(),
        watchSwapUsecase: locator<WatchSwapUsecase>(),
        watchPayjoinUsecase: locator<WatchPayjoinUsecase>(),
        watchTransactionOrderSwapUsecase:
            locator<WatchTransactionOrderSwapUsecase>(),
        labelsFacade: locator<LabelsFacade>(),
        broadcastOriginalTransactionUsecase:
            locator<BroadcastOriginalTransactionUsecase>(),
      ),
    );
  }
}
