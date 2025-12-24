import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/core/infra/di/feature_di_module.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/app_unlock/data/repositories/failed_unlock_attempts_repository_impl.dart';
import 'package:bb_mobile/features/app_unlock/data/services/exponential_timeout_calculator.dart';
import 'package:bb_mobile/features/app_unlock/domain/services/timeout_calculator.dart';
import 'package:bb_mobile/features/app_unlock/domain/usecases/attempt_unlock_with_pin_code_usecase.dart';
import 'package:bb_mobile/features/app_unlock/domain/usecases/check_pin_code_exists_usecase.dart';
import 'package:bb_mobile/features/app_unlock/domain/usecases/get_latest_unlock_attempt_usecase.dart';
import 'package:bb_mobile/features/app_unlock/presentation/bloc/app_unlock_bloc.dart';

class AppUnlockDiModule implements FeatureDiModule {
  @override
  Future<void> registerFrameworksAndDrivers() async {}

  @override
  Future<void> registerDrivenAdapters() async {
    sl.registerLazySingleton<FailedUnlockAttemptsRepository>(
      () => FailedUnlockAttemptsRepository(
        sl(instanceName: LocatorInstanceNameConstants.secureStorageDatasource),
      ),
    );
  }

  @override
  Future<void> registerApplicationServices() async {
    sl.registerLazySingleton<TimeoutCalculator>(
      () => ExponentialTimeoutCalculator(),
    );
  }

  @override
  Future<void> registerUseCases() async {
    sl.registerFactory<GetLatestUnlockAttemptUsecase>(
      () => GetLatestUnlockAttemptUsecase(
        failedUnlockAttemptsRepository: sl(),
        timeoutCalculator: sl(),
      ),
    );
    sl.registerFactory<CheckPinCodeExistsUsecase>(
      () => CheckPinCodeExistsUsecase(pinCodeRepository: sl()),
    );
    sl.registerFactory<AttemptUnlockWithPinCodeUsecase>(
      () => AttemptUnlockWithPinCodeUsecase(
        failedUnlockAttemptsRepository: sl(),
        pinCodeRepository: sl(),
        timeoutCalculator: sl(),
      ),
    );
  }

  @override
  Future<void> registerDrivingAdapters() async {
    sl.registerFactory<AppUnlockBloc>(
      () => AppUnlockBloc(
        checkPinCodeExistsUsecase: sl(),
        getLatestUnlockAttemptUsecase: sl(),
        attemptUnlockWithPinCodeUsecase: sl(),
      ),
    );
  }
}
