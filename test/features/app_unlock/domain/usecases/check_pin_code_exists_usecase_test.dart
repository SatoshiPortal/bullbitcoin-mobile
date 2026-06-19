import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/app_unlock/domain/app_unlock_failure.dart';
import 'package:bb_mobile/features/app_unlock/domain/usecases/check_pin_code_exists_usecase.dart';
import 'package:bb_mobile/features/pin_code/data/repositories/pin_code_repository.dart';
import 'package:bb_mobile/features/pin_code/domain/pin_code_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPinCodeRepository extends Mock implements PinCodeRepository {}

void main() {
  late MockPinCodeRepository pinCodeRepository;
  late CheckPinCodeExistsUsecase usecase;

  setUp(() {
    pinCodeRepository = MockPinCodeRepository();
    usecase = CheckPinCodeExistsUsecase(pinCodeRepository: pinCodeRepository);
  });

  test('returns Ok(true) when pin code is set', () async {
    when(() => pinCodeRepository.isPinCodeSet())
        .thenAnswer((_) async => const Ok(true));

    final result = await usecase.execute();

    expect(result, isA<Ok<bool, AppUnlockFailure>>());
    expect((result as Ok).value, true);
  });

  test('returns Ok(false) when pin code is not set', () async {
    when(() => pinCodeRepository.isPinCodeSet())
        .thenAnswer((_) async => const Ok(false));

    final result = await usecase.execute();

    expect(result, isA<Ok<bool, AppUnlockFailure>>());
    expect((result as Ok).value, false);
  });

  test(
    'returns Err(AppUnlockPinCheckFailure) when repository fails — no raw leak',
    () async {
      when(() => pinCodeRepository.isPinCodeSet()).thenAnswer(
        (_) async => const Err(PinCodeUnexpectedFailure('raw storage error')),
      );

      final result = await usecase.execute();

      expect(result, isA<Err<bool, AppUnlockFailure>>());
      final failure = (result as Err).failure;
      expect(failure, isA<AppUnlockPinCheckFailure>());
      // Raw message must not surface as a new typed failure — it stays in logMessage only
      expect(failure, isNot(isA<AppUnlockUnexpectedFailure>()));
    },
  );
}
