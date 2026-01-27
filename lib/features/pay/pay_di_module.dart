import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/core/infra/di/feature_di_module.dart';
import 'package:bb_mobile/features/pay/domain/create_pay_order_usecase.dart';
import 'package:bb_mobile/features/pay/domain/refresh_pay_order_usecase.dart';
import 'package:bb_mobile/features/pay/presentation/pay_bloc.dart';

class PayDiModule implements FeatureDiModule {
  @override
  Future<void> registerFrameworksAndDrivers() async {}

  @override
  Future<void> registerDrivenAdapters() async {}

  @override
  Future<void> registerApplicationServices() async {}

  @override
  Future<void> registerUseCases() async {
    sl.registerFactory<PlacePayOrderUsecase>(
      () => PlacePayOrderUsecase(
        mainnetExchangeOrderRepository: sl<ExchangeOrderRepository>(
          instanceName: 'mainnetExchangeOrderRepository',
        ),
        testnetExchangeOrderRepository: sl<ExchangeOrderRepository>(
          instanceName: 'testnetExchangeOrderRepository',
        ),
        settingsRepository: sl(),
      ),
    );

    sl.registerFactory<RefreshPayOrderUsecase>(
      () => RefreshPayOrderUsecase(
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
    sl.registerFactory<PayBloc>(
      () => PayBloc(
        getExchangeUserSummaryUsecase: sl(),
        placePayOrderUsecase: sl(),
        refreshPayOrderUsecase: sl(),
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
      ),
    );
  }
}
