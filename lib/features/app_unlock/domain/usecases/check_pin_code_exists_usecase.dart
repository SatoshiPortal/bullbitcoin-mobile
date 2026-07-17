import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/app_unlock/domain/app_unlock_failure.dart';
import 'package:bb_mobile/features/pin_code/data/repositories/pin_code_repository.dart';

class CheckPinCodeExistsUsecase {
  final PinCodeRepository _pinCodeRepository;

  CheckPinCodeExistsUsecase({required this._pinCodeRepository});

  Future<Result<bool, AppUnlockFailure>> execute() => _pinCodeRepository
      .isPinCodeSet()
      .then((r) => r.mapErr((_) => const AppUnlockPinCheckFailure()));
}
