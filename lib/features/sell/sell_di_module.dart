import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/core/infra/di/feature_di_module.dart';
import 'package:bb_mobile/features/sell/domain/create_sell_order_usecase.dart';
import 'package:bb_mobile/features/sell/domain/refresh_sell_order_usecase.dart';
import 'package:bb_mobile/features/sell/presentation/bloc/sell_bloc.dart';

class SellDiModule implements FeatureDiModule {
  @override
  Future<void> registerFrameworksAndDrivers() async {}

  @override
  Future<void> registerDrivenAdapters() async {}

  @override
  Future<void> registerApplicationServices() async {}

  @override
  Future<void> registerUseCases() async {
    sl.registerFactory<CreateSellOrderUsecase>(
      () => CreateSellOrderUsecase(
        mainnetExchangeOrderRepository: sl<ExchangeOrderRepository>(
          instanceName: 'mainnetExchangeOrderRepository',
        ),
        testnetExchangeOrderRepository: sl<ExchangeOrderRepository>(
          instanceName: 'testnetExchangeOrderRepository',
        ),
        settingsRepository: sl(),
      ),
    );

    sl.registerFactory<RefreshSellOrderUsecase>(
      () => RefreshSellOrderUsecase(
        mainnetExchangeOrderRepository: sl<ExchangeOrderRepository>(
          instanceName: 'mainnetExchangeOrderRepository',
        ),
        testnetExchangeOrderRepository: sl<ExchangeOrderRepository>(
          instanceName: 'testnetExchangeOrderRepository',
        ),
        settingsRepository: sl(),
      ),
    );
  }

  @override
  Future<void> registerDrivingAdapters() async {
    sl.registerFactory<SellBloc>(
      () => SellBloc(
        getExchangeUserSummaryUsecase: sl(),
        getSettingsUsecase: sl(),
        createSellOrderUsecase: sl(),
        refreshSellOrderUsecase: sl(),
        prepareBitcoinSendUsecase: sl(),
        prepareLiquidSendUsecase: sl(),
        signBitcoinTxUsecase: sl(),
        signLiquidTxUsecase: sl(),
        broadcastBitcoinTransactionUsecase: sl(),
        broadcastLiquidTransactionUsecase: sl(),
        getNetworkFeesUsecase: sl(),
        calculateLiquidAbsoluteFeesUsecase: sl(),
        calculateBitcoinAbsoluteFeesUsecase: sl(),
        convertSatsToCurrencyAmountUsecase: sl(),
        getAddressAtIndexUsecase: sl(),
        getWalletUtxosUsecase: sl(),
        getOrderUsecase: sl(),
        labelTransactionUsecase: sl(),
      ),
    );
  }
}
