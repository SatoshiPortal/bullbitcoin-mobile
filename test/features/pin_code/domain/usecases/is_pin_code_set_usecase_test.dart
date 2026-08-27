import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/pin_code/data/repositories/pin_code_repository.dart';
import 'package:bb_mobile/features/pin_code/domain/pin_code_failure.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/is_pin_code_set_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPinCodeRepository extends Mock implements PinCodeRepository {}

void main() {
  late MockPinCodeRepository pinCodeRepository;
  late IsPinCodeSetUsecase usecase;

  setUp(() {
    pinCodeRepository = MockPinCodeRepository();
    usecase = IsPinCodeSetUsecase(pinCodeRepository: pinCodeRepository);
  });

  test('preserves a keychain-locked failure', () async {
    when(
      () => pinCodeRepository.isPinCodeSet(),
    ).thenAnswer((_) async => const Err(PinCodeKeychainLockedFailure()));

    final result = await usecase.execute();

    expect(result, isA<Err<bool, PinCodeFailure>>());
    expect((result as Err).failure, isA<PinCodeKeychainLockedFailure>());
  });
}
