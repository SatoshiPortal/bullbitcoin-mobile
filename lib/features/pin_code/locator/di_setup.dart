import 'package:bb_mobile/core/data/datasources/key_value_storage_data_source.dart';
import 'package:bb_mobile/core/locator/di_initializer.dart';
import 'package:bb_mobile/features/pin_code/data/repositories/pin_code_repository_impl.dart';
import 'package:bb_mobile/features/pin_code/domain/repositories/pin_code_repository.dart';
import 'package:bb_mobile/features/pin_code/domain/services/timeout_calculator.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/attempt_unlock_with_pin_code_usecase.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/check_pin_code_exists_usecase.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/get_latest_unlock_attempt_usecase.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/set_pin_code_usecase.dart';
import 'package:bb_mobile/features/pin_code/presentation/blocs/pin_code_setting/pin_code_setting_bloc.dart';
import 'package:bb_mobile/features/pin_code/presentation/blocs/pin_code_unlock/pin_code_unlock_bloc.dart';

void setupPinCodeDependencies() {
  // Repositories
  locator.registerLazySingleton<PinCodeRepository>(
    () => PinCodeRepositoryImpl(
      locator<KeyValueStorageDataSource<String>>(
        instanceName: secureStorageInstanceName,
      ),
    ),
  );

  // Services
  locator.registerLazySingleton<TimeoutCalculator>(
    () => ExponentialTimeoutCalculator(),
  );

  // Use cases
  locator.registerFactory<AttemptUnlockWithPinCodeUseCase>(
    () => AttemptUnlockWithPinCodeUseCase(
      pinCodeRepository: locator<PinCodeRepository>(),
      timeoutCalculator: locator<TimeoutCalculator>(),
    ),
  );
  locator.registerFactory<CheckPinCodeExistsUsecase>(
    () => CheckPinCodeExistsUsecase(
      pinCodeRepository: locator<PinCodeRepository>(),
    ),
  );
  locator.registerFactory<GetLatestUnlockAttemptUseCase>(
    () => GetLatestUnlockAttemptUseCase(
      pinCodeRepository: locator<PinCodeRepository>(),
      timeoutCalculator: locator<TimeoutCalculator>(),
    ),
  );
  locator.registerFactory<SetPinCodeUsecase>(
    () => SetPinCodeUsecase(
      pinCodeRepository: locator<PinCodeRepository>(),
    ),
  );

  // Blocs
  locator.registerFactory<PinCodeSettingBloc>(
    () => PinCodeSettingBloc(
      setPinCodeUsecase: locator<SetPinCodeUsecase>(),
    ),
  );
  locator.registerFactory<PinCodeUnlockBloc>(
    () => PinCodeUnlockBloc(
      checkPinCodeExistsUsecase: locator<CheckPinCodeExistsUsecase>(),
      getLatestUnlockAttemptUseCase: locator<GetLatestUnlockAttemptUseCase>(),
      attemptUnlockWithPinCodeUseCase:
          locator<AttemptUnlockWithPinCodeUseCase>(),
    ),
  );
}
