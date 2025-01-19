import 'package:bb_mobile/features/pin_code/domain/repositories/pin_code_repository.dart';

class SetPinCodeUsecase {
  final PinCodeRepository _pinCodeRepository;

  SetPinCodeUsecase({
    required PinCodeRepository pinCodeRepository,
  }) : _pinCodeRepository = pinCodeRepository;

  Future<void> execute(String newPinCode, {String? oldPinCode}) async {
    if (oldPinCode != null) {
      await _pinCodeRepository.updatePinCode(
        oldPinCode: oldPinCode,
        newPinCode: newPinCode,
      );
    } else {
      await _pinCodeRepository.createPinCode(newPinCode);
    }
  }
}
