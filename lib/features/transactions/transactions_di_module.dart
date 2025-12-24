import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/core/infra/di/feature_di_module.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/transactions/domain/usecases/get_transactions_by_tx_id_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/usecases/get_transactions_usecase.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transactions_cubit.dart';

class TransactionsDiModule implements FeatureDiModule {
  @override
  Future<void> registerFrameworksAndDrivers() async {}

  @override
  Future<void> registerDrivenAdapters() async {}

  @override
  Future<void> registerApplicationServices() async {}

  @override
  Future<void> registerUseCases() async {
    sl.registerFactory<GetTransactionsUsecase>(
      () => GetTransactionsUsecase(
        settingsRepository: sl(),
        walletTransactionRepository: sl(),
        mainnetBoltzSwapRepository: sl<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        testnetBoltzSwapRepository: sl<BoltzSwapRepository>(
          instanceName: LocatorInstanceNameConstants
              .boltzTestnetSwapRepositoryInstanceName,
        ),
        payjoinRepository: sl(),
        mainnetOrderRepository: sl<ExchangeOrderRepository>(
          instanceName: 'mainnetExchangeOrderRepository',
        ),
        testnetOrderRepository: sl<ExchangeOrderRepository>(
          instanceName: 'testnetExchangeOrderRepository',
        ),
        labelExchangeOrdersUsecase: sl(),
      ),
    );

    sl.registerFactory<GetTransactionsByTxIdUsecase>(
      () => GetTransactionsByTxIdUsecase(
        settingsRepository: sl(),
        walletTransactionRepository: sl(),
        mainnetBoltzSwapRepository: sl<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        testnetBoltzSwapRepository: sl<BoltzSwapRepository>(
          instanceName: LocatorInstanceNameConstants
              .boltzTestnetSwapRepositoryInstanceName,
        ),
        payjoinRepository: sl(),
        mainnetOrderRepository: sl<ExchangeOrderRepository>(
          instanceName: 'mainnetExchangeOrderRepository',
        ),
        testnetOrderRepository: sl<ExchangeOrderRepository>(
          instanceName: 'testnetExchangeOrderRepository',
        ),
      ),
    );
  }

  @override
  Future<void> registerDrivingAdapters() async {
    sl.registerFactoryParam<TransactionsCubit, String?, void>(
      (walletId, _) => TransactionsCubit(
        walletId: walletId,
        getTransactionsUsecase: sl(),
        watchStartedWalletSyncsUsecase: sl(),
        watchFinishedWalletSyncsUsecase: sl(),
      ),
    );
    sl.registerFactory<TransactionDetailsCubit>(
      () => TransactionDetailsCubit(
        getWalletUsecase: sl(),
        getTransactionsByTxIdUsecase: sl(),
        watchWalletTransactionByTxIdUsecase: sl(),
        getSwapUsecase: sl(),
        getPayjoinByIdUsecase: sl(),
        getOrderUsecase: sl(),
        watchSwapUsecase: sl(),
        watchPayjoinUsecase: sl(),
        labelTransactionUsecase: sl(),
        deleteLabelUsecase: sl(),
        broadcastOriginalTransactionUsecase: sl(),
        processSwapUsecase: sl(),
        fetchDistinctLabelsUsecase: sl(),
      ),
    );
  }
}
