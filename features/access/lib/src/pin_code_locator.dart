import 'package:access/src/domain/access_inventory.dart';
import 'package:access/src/domain/usecases/delete_pin_code_usecase.dart';
import 'package:access/src/domain/usecases/is_pin_code_set_usecase.dart';
import 'package:access/src/domain/usecases/set_pin_code_usecase.dart';
import 'package:access/src/presentation/bloc/pin_code_setting_bloc.dart';
import 'package:access/src/domain/usecases/check_pin_backup_usecase.dart';
import 'package:get_it/get_it.dart';

class PinCodeLocator {
  static void setup(GetIt locator) {
    // Use cases
    locator.registerFactory<SetPinCodeUsecase>(
      () => SetPinCodeUsecase(inventory: locator<AccessInventory>()),
    );

    locator.registerFactory<DeletePinCodeUsecase>(
      () => DeletePinCodeUsecase(inventory: locator<AccessInventory>()),
    );
    locator.registerFactory<IsPinCodeSetUsecase>(
      () => IsPinCodeSetUsecase(inventory: locator<AccessInventory>()),
    );

    // Blocs
    locator.registerFactory<PinCodeSettingBloc>(
      () => PinCodeSettingBloc(
        isPinCodeSetUsecase: locator<IsPinCodeSetUsecase>(),
        setPinCodeUsecase: locator<SetPinCodeUsecase>(),
        deletePinCodeUsecase: locator<DeletePinCodeUsecase>(),
        checkBackupUsecase: CheckPinBackupUsecase(
          inventory: locator<AccessInventory>(),
        ),
        lockChanges: locator<AccessInventory>().locked,
      ),
    );
  }
}
