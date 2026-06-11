import 'package:bb_mobile/features/pin_code/data/repositories/pin_code_repository.dart';

class IsPinCodeSetUsecase {
  final PinCodeRepository _pinCodeRepository;

  IsPinCodeSetUsecase({required this._pinCodeRepository});

  Future<bool> execute() async => await _pinCodeRepository.isPinCodeSet();
}
