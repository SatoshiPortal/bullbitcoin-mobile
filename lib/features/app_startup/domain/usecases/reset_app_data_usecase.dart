import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/features/pin_code/data/repositories/pin_code_repository.dart';

// On iOS especially, some secure storage data might still be there after the app is uninstalled.
// This use case is used to reset the app data when the app is installed again.
class ResetAppDataUsecase {
  final PinCodeRepository _pinCodeRepository;
  final RecoverBullRepository _recoverBullRepository;

  ResetAppDataUsecase({
    required this._pinCodeRepository,
    required this._recoverBullRepository,
  });

  Future<void> execute() async {
    await _pinCodeRepository.deletePinCode();
    // The telemetry baseline reveals which backups are monitored: it must
    // not survive an app-data reset.
    await _recoverBullRepository.clearTelemetry();
  }
}
