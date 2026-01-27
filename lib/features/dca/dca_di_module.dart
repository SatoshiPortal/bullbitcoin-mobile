import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_user_repository.dart';
import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/core/infra/di/feature_di_module.dart';
import 'package:bb_mobile/features/dca/domain/usecases/set_dca_usecase.dart';
import 'package:bb_mobile/features/dca/domain/usecases/start_dca_usecase.dart';
import 'package:bb_mobile/features/dca/presentation/dca_bloc.dart';

class DcaDiModule implements FeatureDiModule {
  @override
  Future<void> registerFrameworksAndDrivers() async {}

  @override
  Future<void> registerDrivenAdapters() async {}

  @override
  Future<void> registerApplicationServices() async {}

  @override
  Future<void> registerUseCases() async {
    sl.registerFactory<StartDcaUsecase>(
      () => StartDcaUsecase(
        settingsRepository: sl(),
        mainnetExchangeUserRepository: sl<ExchangeUserRepository>(
          instanceName: 'mainnetExchangeUserRepository',
        ),
        testnetExchangeUserRepository: sl<ExchangeUserRepository>(
          instanceName: 'testnetExchangeUserRepository',
        ),
        mainnetExchangeOrderRepository: sl<ExchangeOrderRepository>(
          instanceName: 'mainnetExchangeOrderRepository',
        ),
        testnetExchangeOrderRepository: sl<ExchangeOrderRepository>(
          instanceName: 'testnetExchangeOrderRepository',
        ),
      ),
    );
    sl.registerFactory<SetDcaUsecase>(
      () => SetDcaUsecase(
        mainnetExchangeOrderRepository: sl<ExchangeOrderRepository>(
          instanceName: 'mainnetExchangeOrderRepository',
        ),
        testnetExchangeOrderRepository: sl<ExchangeOrderRepository>(
          instanceName: 'testnetExchangeOrderRepository',
        ),
        wallet: sl(),
        settingsRepository: sl(),
        walletAddressRepository: sl(),
      ),
    );
  }

  @override
  Future<void> registerDrivingAdapters() async {
    sl.registerFactory<DcaBloc>(
      () => DcaBloc(
        startDcaUsecase: sl(),
        setDcaUsecase: sl(),
        saveUserPreferencesUsecase: sl(),
      ),
    );
  }
}
