import 'package:bb_mobile/features/pin_code/domain/repositories/pin_code_repository.dart';

class GetFailedUnlockAttemptsUseCase {
  final PinCodeRepository _pinCodeRepository;

  GetFailedUnlockAttemptsUseCase({
    required PinCodeRepository pinCodeRepository,
  }) : _pinCodeRepository = pinCodeRepository;

  Future<int> execute() async {
    final attempts = await _pinCodeRepository.getFailedUnlockAttempts();
    return attempts;
  }
}
