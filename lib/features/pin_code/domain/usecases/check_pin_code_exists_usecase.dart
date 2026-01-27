import 'package:bb_mobile/features/pin_code/data/repositories/pin_code_repository.dart';

class CheckPinCodeExistsUsecase {
  final PinCodeRepository _pinCodeRepository;

  CheckPinCodeExistsUsecase({required PinCodeRepository pinCodeRepository})
    : _pinCodeRepository = pinCodeRepository;

  Future<bool> execute() async {
    final isPinCodeSet = await _pinCodeRepository.isPinCodeSet();

    return isPinCodeSet;
  }
}
