import 'package:bb_mobile/features/pin_code/domain/repositories/pin_code_repository.dart';

class SetFailedUnlockAttemptsUseCase {
  final PinCodeRepository _pinCodeRepository;

  SetFailedUnlockAttemptsUseCase({
    required PinCodeRepository pinCodeRepository,
  }) : _pinCodeRepository = pinCodeRepository;

  Future<void> execute(int attempts) async {
    return _pinCodeRepository.setFailedUnlockAttempts(attempts);
  }
}
