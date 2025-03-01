import 'package:bb_mobile/pin_code/domain/repositories/pin_code_repository.dart';

class CheckPinCodeExistsUseCase {
  final PinCodeRepository _pinCodeRepository;

  CheckPinCodeExistsUseCase({
    required PinCodeRepository pinCodeRepository,
  }) : _pinCodeRepository = pinCodeRepository;

  Future<bool> execute() async {
    final isPinCodeSet = await _pinCodeRepository.isPinCodeSet();

    return isPinCodeSet;
  }
}
