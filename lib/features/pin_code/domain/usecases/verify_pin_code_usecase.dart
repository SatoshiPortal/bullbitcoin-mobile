import 'package:bb_mobile/features/pin_code/domain/repositories/pin_code_repository.dart';

class VerifyPinCodeUsecase {
  final PinCodeRepository _pinCodeRepository;

  VerifyPinCodeUsecase({
    required PinCodeRepository pinCodeRepository,
  }) : _pinCodeRepository = pinCodeRepository;

  Future<bool> execute(String pinCode) async {
    final isCorrectPinCode = await _pinCodeRepository.checkPinCode(pinCode);

    return isCorrectPinCode;
  }
}
