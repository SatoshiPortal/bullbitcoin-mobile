import 'package:bb_mobile/features/pin_code/data/repositories/pin_code_repository.dart';

class DeletePinCodeUsecase {
  final PinCodeRepository _pinCodeRepository;

  DeletePinCodeUsecase({required this._pinCodeRepository});

  Future<void> execute() async => await _pinCodeRepository.deletePinCode();
}
