import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/core/infra/di/feature_di_module.dart';
import 'package:bb_mobile/features/withdraw/domain/confirm_withdraw_order_usecase.dart';
import 'package:bb_mobile/features/withdraw/domain/create_withdraw_order_usecase.dart';
import 'package:bb_mobile/features/withdraw/presentation/withdraw_bloc.dart';

class WithdrawDiModule implements FeatureDiModule {
  @override
  Future<void> registerFrameworksAndDrivers() async {}

  @override
  Future<void> registerDrivenAdapters() async {}

  @override
  Future<void> registerApplicationServices() async {}

  @override
  Future<void> registerUseCases() async {
    sl.registerLazySingleton<CreateWithdrawOrderUsecase>(
      () => CreateWithdrawOrderUsecase(
        mainnetExchangeOrderRepository: sl<ExchangeOrderRepository>(
          instanceName: 'mainnetExchangeOrderRepository',
        ),
        testnetExchangeOrderRepository: sl<ExchangeOrderRepository>(
          instanceName: 'testnetExchangeOrderRepository',
        ),
        settingsRepository: sl(),
      ),
    );

    sl.registerFactory<ConfirmWithdrawOrderUsecase>(
      () => ConfirmWithdrawOrderUsecase(
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
    sl.registerFactory<WithdrawBloc>(
      () => WithdrawBloc(
        getExchangeUserSummaryUsecase: sl(),
        createWithdrawUsecase: sl(),
        confirmWithdrawUsecase: sl(),
      ),
    );
  }
}
