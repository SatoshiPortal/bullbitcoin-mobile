import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/core/infra/di/feature_di_module.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/pin_code/data/repositories/failed_unlock_attempts_repository_impl.dart';
import 'package:bb_mobile/features/pin_code/data/repositories/pin_code_repository.dart';
import 'package:bb_mobile/features/pin_code/data/services/exponential_timeout_calculator.dart';
import 'package:bb_mobile/features/pin_code/domain/services/timeout_calculator.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/attempt_unlock_with_pin_code_usecase.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/check_pin_code_exists_usecase.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/delete_pin_code_usecase.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/get_latest_unlock_attempt_usecase.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/is_pin_code_set_usecase.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/set_pin_code_usecase.dart';
import 'package:bb_mobile/features/pin_code/presentation/blocs/app_unlock_bloc/app_unlock_bloc.dart';
import 'package:bb_mobile/features/pin_code/presentation/blocs/pin_code_setting_bloc/pin_code_setting_bloc.dart';

class PinCodeDiModule implements FeatureDiModule {
  @override
  Future<void> registerFrameworksAndDrivers() async {}

  @override
  Future<void> registerDrivenAdapters() async {
    sl.registerLazySingleton<PinCodeRepository>(
      () => PinCodeRepository(
        sl<KeyValueStorageDatasource<String>>(
          instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
        ),
      ),
    );
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
    sl.registerFactory<SetPinCodeUsecase>(
      () => SetPinCodeUsecase(pinCodeRepository: sl()),
    );

    sl.registerFactory<DeletePinCodeUsecase>(
      () => DeletePinCodeUsecase(pinCodeRepository: sl()),
    );
    sl.registerFactory<IsPinCodeSetUsecase>(
      () => IsPinCodeSetUsecase(pinCodeRepository: sl()),
    );

    sl.registerFactory<GetLatestUnlockAttemptUsecase>(
      () => GetLatestUnlockAttemptUsecase(
        failedUnlockAttemptsRepository: sl(),
        timeoutCalculator: sl(),
      ),
    );
    // TODO: Check what the difference is between this and IsPinCodeSetUsecase??
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
    sl.registerFactory<PinCodeSettingBloc>(
      () => PinCodeSettingBloc(
        isPinCodeSetUsecase: sl(),
        setPinCodeUsecase: sl(),
        deletePinCodeUsecase: sl(),
      ),
    );

    sl.registerFactory<AppUnlockBloc>(
      () => AppUnlockBloc(
        checkPinCodeExistsUsecase: sl(),
        getLatestUnlockAttemptUsecase: sl(),
        attemptUnlockWithPinCodeUsecase: sl(),
      ),
    );
  }
}
