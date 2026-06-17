import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/pin_code/data/repositories/pin_code_repository.dart';

class CheckPinCodeExistsUsecase {
  final PinCodeRepository _pinCodeRepository;

  CheckPinCodeExistsUsecase({required this._pinCodeRepository});

  Future<bool> execute() async {
    final result = await _pinCodeRepository.isPinCodeSet();
    return switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };
  }
}
