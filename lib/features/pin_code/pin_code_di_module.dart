import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/core/infra/di/feature_di_module.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/pin_code/data/repositories/pin_code_repository.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/delete_pin_code_usecase.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/is_pin_code_set_usecase.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/set_pin_code_usecase.dart';
import 'package:bb_mobile/features/pin_code/presentation/bloc/pin_code_setting_bloc.dart';

class PinCodeDiModule implements FeatureDiModule {
  @override
  Future<void> registerFrameworksAndDrivers() async {}

  @override
  Future<void> registerDrivenAdapters() async {
    // TODO: check what can be moved to core (since the pin code repository is needed both in settings as in app unlock)
    sl.registerLazySingleton<PinCodeRepository>(
      () => PinCodeRepository(
        sl<KeyValueStorageDatasource<String>>(
          instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
        ),
      ),
    );
  }

  @override
  Future<void> registerApplicationServices() async {}

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
  }
}
