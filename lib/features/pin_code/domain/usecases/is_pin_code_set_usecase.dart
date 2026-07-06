import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/pin_code/data/repositories/pin_code_repository.dart';
import 'package:bb_mobile/features/pin_code/domain/pin_code_failure.dart';

class IsPinCodeSetUsecase {
  final PinCodeRepository _pinCodeRepository;
  IsPinCodeSetUsecase({required this._pinCodeRepository});

  Future<Result<bool, PinCodeFailure>> execute() =>
      _pinCodeRepository.isPinCodeSet();
}
