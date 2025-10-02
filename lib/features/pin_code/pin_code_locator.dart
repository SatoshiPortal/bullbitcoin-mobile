import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/pin_code/data/repositories/pin_code_repository_impl.dart';
import 'package:bb_mobile/features/pin_code/domain/repositories/pin_code_repository.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/delete_pin_code_usecase.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/set_pin_code_usecase.dart';
import 'package:bb_mobile/features/pin_code/presentation/bloc/pin_code_setting_bloc.dart';
import 'package:bb_mobile/locator.dart';

class PinCodeLocator {
  static void setup() {
    // Todo: check what can be moved to core (since the pin code repository is needed both in settings as in app unlock)

    // Repositories
    locator.registerLazySingleton<PinCodeRepository>(
      () => PinCodeRepositoryImpl(
        locator<KeyValueStorageDatasource<String>>(
          instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
        ),
      ),
    );

    // Use cases
    locator.registerFactory<SetPinCodeUsecase>(
      () => SetPinCodeUsecase(pinCodeRepository: locator<PinCodeRepository>()),
    );

    locator.registerFactory<DeletePinCodeUsecase>(
      () =>
          DeletePinCodeUsecase(pinCodeRepository: locator<PinCodeRepository>()),
    );

    // Blocs
    locator.registerFactory<PinCodeSettingBloc>(
      () => PinCodeSettingBloc(
        setPinCodeUsecase: locator<SetPinCodeUsecase>(),
        deletePinCodeUsecase: locator<DeletePinCodeUsecase>(),
      ),
    );
  }
}
