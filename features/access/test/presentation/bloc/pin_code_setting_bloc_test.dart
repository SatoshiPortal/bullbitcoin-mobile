import 'dart:async';

import 'package:primitives/primitives.dart';
import 'package:access/src/domain/access_failure.dart';
import 'package:access/src/domain/usecases/delete_pin_code_usecase.dart';
import 'package:access/src/domain/usecases/is_pin_code_set_usecase.dart';
import 'package:access/src/domain/usecases/set_pin_code_usecase.dart';
import 'package:access/src/presentation/bloc/pin_code_setting_bloc.dart';
import 'package:access/src/domain/usecases/check_pin_backup_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSetPinCodeUsecase extends Mock implements SetPinCodeUsecase {}

class MockDeletePinCodeUsecase extends Mock implements DeletePinCodeUsecase {}

class MockIsPinCodeSetUsecase extends Mock implements IsPinCodeSetUsecase {}

class MockCheckPinBackupUsecase extends Mock implements CheckPinBackupUsecase {}

void main() {
  test(
    'a grant without revocation does not suppress a committed result',
    () async {
      final lockChanges = StreamController<bool>.broadcast(sync: true);
      final deleting = Completer<Result<void, AccessFailure>>();
      final delete = MockDeletePinCodeUsecase();
      final isSet = MockIsPinCodeSetUsecase();
      when(() => delete.execute()).thenAnswer((_) => deleting.future);
      when(() => isSet.execute()).thenAnswer((_) async => const Ok(true));
      final bloc = PinCodeSettingBloc(
        setPinCodeUsecase: MockSetPinCodeUsecase(),
        deletePinCodeUsecase: delete,
        isPinCodeSetUsecase: isSet,
        checkBackupUsecase: MockCheckPinBackupUsecase(),
        lockChanges: lockChanges.stream,
      );
      await bloc.stream.firstWhere(
        (s) => s.status == PinCodeSettingStatus.unlock,
      );
      bloc.add(const PinCodeDelete());
      await untilCalled(() => delete.execute());
      lockChanges.add(false);
      final completed = bloc.stream.firstWhere(
        (s) => s.status == PinCodeSettingStatus.deleted,
      );
      deleting.complete(const Ok(null));
      await completed.timeout(const Duration(seconds: 5));
      await bloc.close();
      await lockChanges.close();
    },
  );

  // The backup check gates whether the user is allowed to set a PIN at all.
  // If it cannot be answered, the safe answer is "not backed up": telling
  // someone their funds are backed up when we do not know is the one outcome
  // that loses money.
  group('backup gate fails closed', () {
    PinCodeSettingBloc buildBloc(MockCheckPinBackupUsecase checkBackup) {
      final isPinCodeSet = MockIsPinCodeSetUsecase();
      when(() => isPinCodeSet.execute())
          .thenAnswer((_) async => const Ok(false));
      return PinCodeSettingBloc(
        setPinCodeUsecase: MockSetPinCodeUsecase(),
        deletePinCodeUsecase: MockDeletePinCodeUsecase(),
        isPinCodeSetUsecase: isPinCodeSet,
        checkBackupUsecase: checkBackup,
        lockChanges: const Stream.empty(),
      );
    }

    test(
      'routes to backupRequired when no verified backup is available',
      () async {
        final checkBackup = MockCheckPinBackupUsecase();
        when(() => checkBackup.execute())
            .thenAnswer((_) async => const Err(AccessBackupRequiredFailure(1)));
        final bloc = buildBloc(checkBackup);
        addTearDown(bloc.close);

        await bloc.stream.firstWhere(
          (state) => state.status != PinCodeSettingStatus.initializing,
        );

        expect(bloc.state.status, PinCodeSettingStatus.backupRequired);
        // The other feature's failure is a routing input here, not something
        // this screen shows.
        expect(bloc.state.failure, isA<AccessBackupRequiredFailure>());
      },
    );

    test('routes to choose when a backup exists', () async {
      final checkBackup = MockCheckPinBackupUsecase();
      when(() => checkBackup.execute()).thenAnswer((_) async => const Ok(null));
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
    when(() => isPinCodeSet.execute()).thenAnswer(
      (_) async => const Err(AccessPinSettingsKeychainLockedFailure()),
    );
    final bloc = PinCodeSettingBloc(
      setPinCodeUsecase: MockSetPinCodeUsecase(),
      deletePinCodeUsecase: MockDeletePinCodeUsecase(),
      isPinCodeSetUsecase: isPinCodeSet,
      checkBackupUsecase: MockCheckPinBackupUsecase(),
      lockChanges: const Stream.empty(),
    );
    addTearDown(bloc.close);

    await bloc.stream.firstWhere(
      (state) => state.status == PinCodeSettingStatus.failure,
    );

    expect(bloc.state.failure, isA<AccessPinSettingsKeychainLockedFailure>());
  });

  test('settings start emits failure when the keychain is locked', () async {
    final isPinCodeSet = MockIsPinCodeSetUsecase();
    when(() => isPinCodeSet.execute()).thenAnswer((_) async => const Ok(true));
    final bloc = PinCodeSettingBloc(
      setPinCodeUsecase: MockSetPinCodeUsecase(),
      deletePinCodeUsecase: MockDeletePinCodeUsecase(),
      isPinCodeSetUsecase: isPinCodeSet,
      checkBackupUsecase: MockCheckPinBackupUsecase(),
      lockChanges: const Stream.empty(),
    );
    addTearDown(bloc.close);
    await bloc.stream.firstWhere(
      (state) => state.status == PinCodeSettingStatus.unlock,
    );
    when(() => isPinCodeSet.execute()).thenAnswer(
      (_) async => const Err(AccessPinSettingsKeychainLockedFailure()),
    );

    bloc.add(const PinCodeSettingStarted());
    await bloc.stream.firstWhere(
      (state) => state.status == PinCodeSettingStatus.failure,
    );

    expect(bloc.state.failure, isA<AccessPinSettingsKeychainLockedFailure>());
  });
}
