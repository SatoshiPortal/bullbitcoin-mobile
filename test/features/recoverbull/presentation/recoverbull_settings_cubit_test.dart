import 'package:bb_mobile/features/recoverbull/domain/usecases/has_current_encrypted_backup_usecase.dart';
import 'package:bb_mobile/features/recoverbull/presentation/recoverbull_settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockHasCurrentEncryptedBackupUsecase extends Mock
    implements HasCurrentEncryptedBackupUsecase {}

void main() {
  late _MockHasCurrentEncryptedBackupUsecase hasCurrentEncryptedBackup;

  setUp(() {
    hasCurrentEncryptedBackup = _MockHasCurrentEncryptedBackupUsecase();
  });

  test(
    'publishes whether the current wallet has an encrypted backup',
    () async {
      when(
        () => hasCurrentEncryptedBackup.execute(),
      ).thenAnswer((_) async => true);
      final cubit = RecoverBullSettingsCubit(hasCurrentEncryptedBackup);

      await cubit.load();

      expect(cubit.state, isTrue);
      await cubit.close();
    },
  );

  test('fails closed when the backup status cannot be read', () async {
    when(
      () => hasCurrentEncryptedBackup.execute(),
    ).thenThrow(Exception('storage unavailable'));
    final cubit = RecoverBullSettingsCubit(hasCurrentEncryptedBackup);

    await cubit.load();

    expect(cubit.state, isFalse);
    await cubit.close();
  });
}
