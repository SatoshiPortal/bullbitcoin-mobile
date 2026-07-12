import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/keychain_locked_exception.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/pin_code/data/repositories/pin_code_repository.dart';
import 'package:bb_mobile/features/pin_code/domain/pin_code_failure.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/delete_pin_code_usecase.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/is_pin_code_set_usecase.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/set_pin_code_usecase.dart';
import 'package:bb_mobile/features/pin_code/presentation/bloc/pin_code_setting_bloc.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/check_backup_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPinCodeRepository extends Mock implements PinCodeRepository {}

class _MockSetPinCodeUsecase extends Mock implements SetPinCodeUsecase {}

class _MockDeletePinCodeUsecase extends Mock implements DeletePinCodeUsecase {}

class _MockCheckBackupUsecase extends Mock implements CheckBackupUsecase {}

void main() {
  late _MockPinCodeRepository pinCodeRepository;
  late _MockSetPinCodeUsecase setPinCodeUsecase;
  late _MockDeletePinCodeUsecase deletePinCodeUsecase;
  late _MockCheckBackupUsecase checkBackupUsecase;

  setUp(() {
    pinCodeRepository = _MockPinCodeRepository();
    setPinCodeUsecase = _MockSetPinCodeUsecase();
    deletePinCodeUsecase = _MockDeletePinCodeUsecase();
    checkBackupUsecase = _MockCheckBackupUsecase();
  });

  PinCodeSettingBloc buildBloc() => PinCodeSettingBloc(
    isPinCodeSetUsecase: IsPinCodeSetUsecase(
      pinCodeRepository: pinCodeRepository,
    ),
    setPinCodeUsecase: setPinCodeUsecase,
    deletePinCodeUsecase: deletePinCodeUsecase,
    checkBackupUsecase: checkBackupUsecase,
  );

  group('PinCodeSettingInitialized (auto-dispatched on construction)', () {
    test(
      'a KeychainLockedException from isPinCodeSet is caught and emits a '
      'failure state instead of escaping the handler unhandled',
      () async {
        when(
          () => pinCodeRepository.isPinCodeSet(),
        ).thenAnswer((_) async => throw const KeychainLockedException());

        final bloc = buildBloc();
        await pumpEventQueue();

        expect(bloc.state.status, PinCodeSettingStatus.failure);
        expect(bloc.state.failure, isA<PinCodeUnexpectedFailure>());

        await bloc.close();
      },
    );

    test('a normal Ok(true) still goes straight to unlock', () async {
      when(
        () => pinCodeRepository.isPinCodeSet(),
      ).thenAnswer((_) async => const Ok(true));

      final bloc = buildBloc();
      await pumpEventQueue();

      expect(bloc.state.status, PinCodeSettingStatus.unlock);
      expect(bloc.state.isPinCodeSet, isTrue);

      await bloc.close();
    });
  });

  group('PinCodeSettingStarted', () {
    test(
      'a KeychainLockedException from isPinCodeSet is caught and emits a '
      'failure state instead of escaping the handler unhandled',
      () async {
        when(
          () => pinCodeRepository.isPinCodeSet(),
        ).thenAnswer((_) async => const Ok(false));
        when(
          () => checkBackupUsecase.execute(),
        ).thenAnswer((_) async => true);
        final bloc = buildBloc();
        await pumpEventQueue();

        when(
          () => pinCodeRepository.isPinCodeSet(),
        ).thenAnswer((_) async => throw const KeychainLockedException());
        bloc.add(const PinCodeSettingStarted());
        await pumpEventQueue();

        expect(bloc.state.status, PinCodeSettingStatus.failure);
        expect(bloc.state.failure, isA<PinCodeUnexpectedFailure>());

        await bloc.close();
      },
    );
  });
}
