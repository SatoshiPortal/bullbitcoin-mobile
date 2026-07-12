import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/keychain_locked_exception.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/app_unlock/domain/app_unlock_failure.dart';
import 'package:bb_mobile/features/app_unlock/domain/usecases/attempt_unlock_with_pin_code_usecase.dart';
import 'package:bb_mobile/features/app_unlock/domain/usecases/check_pin_code_exists_usecase.dart';
import 'package:bb_mobile/features/app_unlock/domain/usecases/get_latest_unlock_attempt_usecase.dart';
import 'package:bb_mobile/features/app_unlock/presentation/bloc/app_unlock_bloc.dart';
import 'package:bb_mobile/features/pin_code/data/repositories/pin_code_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPinCodeRepository extends Mock implements PinCodeRepository {}

class _MockGetLatestUnlockAttemptUsecase extends Mock
    implements GetLatestUnlockAttemptUsecase {}

class _MockAttemptUnlockWithPinCodeUsecase extends Mock
    implements AttemptUnlockWithPinCodeUsecase {}

void main() {
  late _MockPinCodeRepository pinCodeRepository;
  late _MockGetLatestUnlockAttemptUsecase getLatestUnlockAttemptUsecase;
  late _MockAttemptUnlockWithPinCodeUsecase attemptUnlockWithPinCodeUsecase;
  late AppUnlockBloc bloc;

  setUp(() {
    pinCodeRepository = _MockPinCodeRepository();
    getLatestUnlockAttemptUsecase = _MockGetLatestUnlockAttemptUsecase();
    attemptUnlockWithPinCodeUsecase = _MockAttemptUnlockWithPinCodeUsecase();
    bloc = AppUnlockBloc(
      checkPinCodeExistsUsecase: CheckPinCodeExistsUsecase(
        pinCodeRepository: pinCodeRepository,
      ),
      getLatestUnlockAttemptUsecase: getLatestUnlockAttemptUsecase,
      attemptUnlockWithPinCodeUsecase: attemptUnlockWithPinCodeUsecase,
    );
  });

  tearDown(() => bloc.close());

  group('AppUnlockStarted', () {
    test(
      'a KeychainLockedException from isPinCodeSet (rethrown, not wrapped '
      'in Err) is caught and emits a failure state instead of escaping '
      'the handler unhandled',
      () async {
        when(
          () => pinCodeRepository.isPinCodeSet(),
        ).thenAnswer((_) async => throw const KeychainLockedException());

        bloc.add(const AppUnlockStarted());
        await pumpEventQueue();

        expect(bloc.state.status, AppUnlockStatus.failure);
        expect(bloc.state.failure, isA<AppUnlockPinCheckFailure>());
      },
    );

    test('a normal Ok(false) still goes straight to success', () async {
      when(
        () => pinCodeRepository.isPinCodeSet(),
      ).thenAnswer((_) async => const Ok(false));

      bloc.add(const AppUnlockStarted());
      await pumpEventQueue();

      expect(bloc.state.status, AppUnlockStatus.success);
    });
  });
}
