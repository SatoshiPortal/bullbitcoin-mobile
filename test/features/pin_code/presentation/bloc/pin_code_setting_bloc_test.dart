import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/pin_code/domain/pin_code_failure.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/delete_pin_code_usecase.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/is_pin_code_set_usecase.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/set_pin_code_usecase.dart';
import 'package:bb_mobile/features/pin_code/presentation/bloc/pin_code_setting_bloc.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/test_wallet_backup_failure.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/check_backup_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSetPinCodeUsecase extends Mock implements SetPinCodeUsecase {}

class MockDeletePinCodeUsecase extends Mock implements DeletePinCodeUsecase {}

class MockIsPinCodeSetUsecase extends Mock implements IsPinCodeSetUsecase {}

class MockCheckBackupUsecase extends Mock implements CheckBackupUsecase {}

void main() {
  // The backup check gates whether the user is allowed to set a PIN at all.
  // If it cannot be answered, the safe answer is "not backed up": telling
  // someone their funds are backed up when we do not know is the one outcome
  // that loses money.
  group('backup gate fails closed', () {
    PinCodeSettingBloc buildBloc(MockCheckBackupUsecase checkBackup) {
      final isPinCodeSet = MockIsPinCodeSetUsecase();
      when(
        () => isPinCodeSet.execute(),
      ).thenAnswer((_) async => const Ok(false));
      return PinCodeSettingBloc(
        setPinCodeUsecase: MockSetPinCodeUsecase(),
        deletePinCodeUsecase: MockDeletePinCodeUsecase(),
        isPinCodeSetUsecase: isPinCodeSet,
        checkBackupUsecase: checkBackup,
      );
    }

    test('routes to backupRequired when the backup check fails', () async {
      final checkBackup = MockCheckBackupUsecase();
      when(() => checkBackup.execute()).thenAnswer(
        (_) async =>
            const Err(TestWalletBackupWalletsUnavailableFailure('locked')),
      );
      final bloc = buildBloc(checkBackup);
      addTearDown(bloc.close);

      await bloc.stream.firstWhere(
        (state) => state.status != PinCodeSettingStatus.initializing,
      );

      expect(bloc.state.status, PinCodeSettingStatus.backupRequired);
      // The other feature's failure is a routing input here, not something
      // this screen shows.
      expect(bloc.state.failure, isNull);
    });

    test('routes to choose when a backup exists', () async {
      final checkBackup = MockCheckBackupUsecase();
      when(() => checkBackup.execute()).thenAnswer((_) async => const Ok(true));
      final bloc = buildBloc(checkBackup);
      addTearDown(bloc.close);

      await bloc.stream.firstWhere(
        (state) => state.status != PinCodeSettingStatus.initializing,
      );

      expect(bloc.state.status, PinCodeSettingStatus.choose);
    });
  });

  test('initialization emits failure when the keychain is locked', () async {
    final isPinCodeSet = MockIsPinCodeSetUsecase();
    when(
      () => isPinCodeSet.execute(),
    ).thenAnswer((_) async => const Err(PinCodeKeychainLockedFailure()));
    final bloc = PinCodeSettingBloc(
      setPinCodeUsecase: MockSetPinCodeUsecase(),
      deletePinCodeUsecase: MockDeletePinCodeUsecase(),
      isPinCodeSetUsecase: isPinCodeSet,
      checkBackupUsecase: MockCheckBackupUsecase(),
    );
    addTearDown(bloc.close);

    await bloc.stream.firstWhere(
      (state) => state.status == PinCodeSettingStatus.failure,
    );

    expect(bloc.state.failure, isA<PinCodeKeychainLockedFailure>());
  });

  test('settings start emits failure when the keychain is locked', () async {
    final isPinCodeSet = MockIsPinCodeSetUsecase();
    when(() => isPinCodeSet.execute()).thenAnswer((_) async => const Ok(true));
    final bloc = PinCodeSettingBloc(
      setPinCodeUsecase: MockSetPinCodeUsecase(),
      deletePinCodeUsecase: MockDeletePinCodeUsecase(),
      isPinCodeSetUsecase: isPinCodeSet,
      checkBackupUsecase: MockCheckBackupUsecase(),
    );
    addTearDown(bloc.close);
    await bloc.stream.firstWhere(
      (state) => state.status == PinCodeSettingStatus.unlock,
    );
    when(
      () => isPinCodeSet.execute(),
    ).thenAnswer((_) async => const Err(PinCodeKeychainLockedFailure()));

    bloc.add(const PinCodeSettingStarted());
    await bloc.stream.firstWhere(
      (state) => state.status == PinCodeSettingStatus.failure,
    );

    expect(bloc.state.failure, isA<PinCodeKeychainLockedFailure>());
  });
}
