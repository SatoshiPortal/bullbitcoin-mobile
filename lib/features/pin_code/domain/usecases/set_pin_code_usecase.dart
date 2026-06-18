import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/pin_code/data/repositories/pin_code_repository.dart';
import 'package:bb_mobile/features/pin_code/domain/pin_code_failure.dart';

class SetPinCodeUsecase {
  final PinCodeRepository _pinCodeRepository;
  SetPinCodeUsecase({required this._pinCodeRepository});

  Future<Result<Null, PinCodeFailure>> execute(String pinCode) =>
      _pinCodeRepository.setPinCode(pinCode);
}
