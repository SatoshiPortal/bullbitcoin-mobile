import 'package:bb_mobile/_core/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/_utils/constants.dart';
import 'package:bb_mobile/app_unlock/data/repositories/failed_unlock_attempts_repository_impl.dart';
import 'package:bb_mobile/app_unlock/data/services/exponential_timeout_calculator.dart';
import 'package:bb_mobile/app_unlock/domain/repositories/failed_unlock_attempts_repository.dart';
import 'package:bb_mobile/app_unlock/domain/services/timeout_calculator.dart';
import 'package:bb_mobile/app_unlock/domain/usecases/attempt_unlock_with_pin_code_usecase.dart';
import 'package:bb_mobile/app_unlock/domain/usecases/check_pin_code_exists_usecase.dart';
import 'package:bb_mobile/app_unlock/domain/usecases/get_latest_unlock_attempt_usecase.dart';
import 'package:bb_mobile/app_unlock/presentation/bloc/app_unlock_bloc.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/pin_code/domain/repositories/pin_code_repository.dart';

class AppUnlockLocator {
  static void setup() {
    // Repositories
    locator.registerLazySingleton<FailedUnlockAttemptsRepository>(
      () => FailedUnlockAttemptsRepositoryImpl(
        locator<KeyValueStorageDatasource<String>>(
          instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
        ),
      ),
    );

    // Services
    locator.registerLazySingleton<TimeoutCalculator>(
      () => ExponentialTimeoutCalculator(),
    );

    // Use cases
    locator.registerFactory<GetLatestUnlockAttemptUsecase>(
      () => GetLatestUnlockAttemptUsecase(
        failedUnlockAttemptsRepository:
            locator<FailedUnlockAttemptsRepository>(),
        timeoutCalculator: locator<TimeoutCalculator>(),
      ),
    );
    locator.registerFactory<CheckPinCodeExistsUsecase>(
      () => CheckPinCodeExistsUsecase(
        pinCodeRepository: locator<PinCodeRepository>(),
      ),
    );
    locator.registerFactory<AttemptUnlockWithPinCodeUsecase>(
      () => AttemptUnlockWithPinCodeUsecase(
        failedUnlockAttemptsRepository:
            locator<FailedUnlockAttemptsRepository>(),
        pinCodeRepository: locator<PinCodeRepository>(),
        timeoutCalculator: locator<TimeoutCalculator>(),
      ),
    );

    // Blocs
    locator.registerFactory<AppUnlockBloc>(
      () => AppUnlockBloc(
        checkPinCodeExistsUsecase: locator<CheckPinCodeExistsUsecase>(),
        getLatestUnlockAttemptUsecase: locator<GetLatestUnlockAttemptUsecase>(),
        attemptUnlockWithPinCodeUsecase:
            locator<AttemptUnlockWithPinCodeUsecase>(),
      ),
    );
  }
}
