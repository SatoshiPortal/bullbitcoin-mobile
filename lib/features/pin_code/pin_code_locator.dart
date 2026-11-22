import 'package:secrets/secrets.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/delete_pin_code_usecase.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/is_pin_code_set_usecase.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/set_pin_code_usecase.dart';
import 'package:bb_mobile/features/pin_code/presentation/bloc/pin_code_setting_bloc.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/check_pin_backup_usecase.dart';
import 'package:get_it/get_it.dart';

class PinCodeLocator {
  static void setup(
    GetIt locator, {
    required Future<bool> Function() hasVerifiedBackup,
  }) {
    // Use cases
    locator.registerFactory<SetPinCodeUsecase>(
      () =>
          SetPinCodeUsecase(accessKeychain: locator<Secrets>().accessKeychain),
    );

    locator.registerFactory<DeletePinCodeUsecase>(
      () => DeletePinCodeUsecase(
        accessKeychain: locator<Secrets>().accessKeychain,
      ),
    );
    locator.registerFactory<IsPinCodeSetUsecase>(
      () => IsPinCodeSetUsecase(
        accessKeychain: locator<Secrets>().accessKeychain,
      ),
    );

    // Blocs
    locator.registerFactory<PinCodeSettingBloc>(
      () => PinCodeSettingBloc(
        isPinCodeSetUsecase: locator<IsPinCodeSetUsecase>(),
        setPinCodeUsecase: locator<SetPinCodeUsecase>(),
        deletePinCodeUsecase: locator<DeletePinCodeUsecase>(),
        checkBackupUsecase: CheckPinBackupUsecase(hasVerifiedBackup),
      ),
    );
  }
}
