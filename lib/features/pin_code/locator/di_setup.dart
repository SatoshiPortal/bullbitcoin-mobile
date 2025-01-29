import 'package:bb_mobile/core/data/datasources/key_value_storage_data_source.dart';
import 'package:bb_mobile/core/locator/di_initializer.dart';
import 'package:bb_mobile/features/pin_code/data/repositories/pin_code_repository_impl.dart';
import 'package:bb_mobile/features/pin_code/domain/repositories/pin_code_repository.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/check_pin_code_exists_usecase.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/set_pin_code_usecase.dart';
import 'package:bb_mobile/features/pin_code/presentation/bloc/pin_code_setting_bloc.dart';

void setupPinCodeDependencies() {
  // Repositories
  locator.registerLazySingleton<PinCodeRepository>(
    () => PinCodeRepositoryImpl(
      locator<KeyValueStorageDataSource<String>>(
        instanceName: secureStorageInstanceName,
      ),
    ),
  );

  // Use cases
  locator.registerFactory<CheckPinCodeExistsUsecase>(
    () => CheckPinCodeExistsUsecase(
      pinCodeRepository: locator<PinCodeRepository>(),
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
}
