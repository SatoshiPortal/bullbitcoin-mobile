import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/manage_data_backup_files_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../vault_recovery_fixture.dart';

class _Backups extends Mock implements WalletBackupFacade {}

void main() {
  late _Backups backups;
  setUp(() => backups = _Backups());
  test('picker cancellation never inspects or applies a file', () async {
    when(backups.pickFile).thenAnswer((_) async => const Ok(null));
    final result = await InspectDataBackupFileUsecase(backups).execute();
    expect((result as Ok).value, isNull);
    verifyNever(() => backups.compareFile(any()));
  });
  test(
    'invalid input is rejected without returning its source to presentation',
    () async {
      when(backups.pickFile).thenAnswer((_) async => const Ok('invalid input'));
      when(
        () => backups.compareFile('invalid input'),
      ).thenAnswer((_) async => const Err(WalletBackupInvalidFailure()));
      expect(await InspectDataBackupFileUsecase(backups).execute(), isA<Err>());
    },
  );
  test(
    'a validated file remains inspectable when the server is unavailable',
    () async {
      final comparison = WalletBackupFileComparison(
        file: WalletBackupFile(
          format: WalletBackupFileFormat.readable,
          snapshot: vaultRecoveryFixture().inspection.snapshot!,
          createdAt: DateTime.utc(2026, 9, 19),
        ),
        server: null,
        automaticBackupEnabled: false,
        serverFailure: const WalletBackupNetworkFailure(),
      );
      when(
        backups.pickFile,
      ).thenAnswer((_) async => const Ok('validated file'));
      when(
        () => backups.compareFile('validated file'),
      ).thenAnswer((_) async => Ok(comparison));
      final result = await InspectDataBackupFileUsecase(backups).execute();
      final value =
          (result
                  as Ok<
                    ({String source, WalletBackupFileComparison comparison})?,
                    BackupSettingsFailure
                  >)
              .value!;
      expect(value.comparison, same(comparison));
      expect(value.source, 'validated file');
      verify(() => backups.compareFile('validated file')).called(1);
    },
  );
  test('a cancelled save is not a successful export', () async {
    when(
      () => backups.exportFile(
        WalletBackupFileFormat.encrypted,
        confirmed: false,
      ),
    ).thenAnswer((_) async => const Ok(false));
    final result = await ExportDataBackupFileUsecase(
      backups,
    ).execute(WalletBackupFileFormat.encrypted);
    expect((result as Ok).value, isFalse);
  });
}
