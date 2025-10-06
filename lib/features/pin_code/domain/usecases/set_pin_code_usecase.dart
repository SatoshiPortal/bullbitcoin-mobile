import 'package:bb_mobile/features/pin_code/data/repositories/pin_code_repository.dart';

class SetPinCodeUsecase {
  final PinCodeRepository _pinCodeRepository;

  SetPinCodeUsecase({required PinCodeRepository pinCodeRepository})
    : _pinCodeRepository = pinCodeRepository;

  Future<void> execute(String pinCode) async {
    await _pinCodeRepository.setPinCode(pinCode);
  }
}
