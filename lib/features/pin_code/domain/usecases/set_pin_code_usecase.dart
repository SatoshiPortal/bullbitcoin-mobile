import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/pin_code/data/repositories/pin_code_repository.dart';

class SetPinCodeUsecase {
  final PinCodeRepository _pinCodeRepository;
  SetPinCodeUsecase({required this._pinCodeRepository});

  Future<Result<Null>> execute(String pinCode) =>
      _pinCodeRepository.setPinCode(pinCode);
}
