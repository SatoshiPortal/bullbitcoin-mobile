import 'package:bb_mobile/features/recoverbull/recover_remote_keychain_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletBackupFacade extends Mock implements WalletBackupFacade {}

void main() {
  late _MockWalletBackupFacade backup;
  late RecoverBullRemoteKeychainUsecase usecase;

  setUp(() {
    backup = _MockWalletBackupFacade();
    usecase = RecoverBullRemoteKeychainUsecase(backup);
  });

  for (final status in [
    WalletBackupRecoveryStatus.noBackup,
    WalletBackupRecoveryStatus.restored,
  ]) {
    test('$status completes optional Data Backup recovery', () async {
      when(
        () => backup.recover(defaultCreatedWalletIds: {'bitcoin', 'liquid'}),
      ).thenAnswer((_) async => WalletBackupRecoveryResult(status: status));

      expect(
        await usecase.execute(defaultCreatedWalletIds: {'bitcoin', 'liquid'}),
        isTrue,
      );
    });
  }

  test(
    'reports an incomplete optional recovery without failing money recovery',
    () async {
      when(
        () => backup.recover(defaultCreatedWalletIds: {'bitcoin', 'liquid'}),
      ).thenAnswer(
        (_) async => const WalletBackupRecoveryResult(
          status: WalletBackupRecoveryStatus.partiallyRestored,
          restoredCount: 2,
          failedCount: 1,
        ),
      );

      expect(
        await usecase.execute(defaultCreatedWalletIds: {'bitcoin', 'liquid'}),
        isFalse,
      );
    },
  );
}
