import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/app_unlock/domain/app_unlock_failure.dart';
import 'package:bb_mobile/features/app_unlock/domain/usecases/attempt_unlock_with_pin_code_usecase.dart';
import 'package:bb_mobile/features/app_unlock/domain/usecases/check_pin_code_exists_usecase.dart';
import 'package:bb_mobile/features/app_unlock/domain/usecases/get_latest_unlock_attempt_usecase.dart';
import 'package:bb_mobile/features/app_unlock/presentation/bloc/app_unlock_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCheckPinCodeExistsUsecase extends Mock
    implements CheckPinCodeExistsUsecase {}

class MockGetLatestUnlockAttemptUsecase extends Mock
    implements GetLatestUnlockAttemptUsecase {}

class MockAttemptUnlockWithPinCodeUsecase extends Mock
    implements AttemptUnlockWithPinCodeUsecase {}

void main() {
  test('emits failure when the keychain is locked', () async {
    final checkPinCodeExists = MockCheckPinCodeExistsUsecase();
    when(
      () => checkPinCodeExists.execute(),
    ).thenAnswer((_) async => const Err(AppUnlockKeychainLockedFailure()));
    final bloc = AppUnlockBloc(
      checkPinCodeExistsUsecase: checkPinCodeExists,
      getLatestUnlockAttemptUsecase: MockGetLatestUnlockAttemptUsecase(),
      attemptUnlockWithPinCodeUsecase: MockAttemptUnlockWithPinCodeUsecase(),
    );
    addTearDown(bloc.close);

    bloc.add(const AppUnlockStarted());
    await bloc.stream.firstWhere(
      (state) => state.status == AppUnlockStatus.failure,
    );

    expect(bloc.state.failure, isA<AppUnlockKeychainLockedFailure>());
  });
}
