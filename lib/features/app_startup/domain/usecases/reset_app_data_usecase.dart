import 'package:bb_mobile/features/pin_code/data/repositories/pin_code_repository.dart';

// On iOS especially, some secure storage data might still be there after the app is uninstalled.
// This use case is used to reset the app data when the app is installed again.
class ResetAppDataUsecase {
  final PinCodeRepository _pinCodeRepository;

  ResetAppDataUsecase({required PinCodeRepository pinCodeRepository})
    : _pinCodeRepository = pinCodeRepository;

  Future<void> execute() async {
    await _pinCodeRepository.deletePinCode();
  }
}
