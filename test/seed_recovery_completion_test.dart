import 'package:bb_mobile/seed_recovery_completion.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletBackupFacade extends Mock implements WalletBackupFacade {}

void main() {
  late _MockWalletBackupFacade backup;

  setUp(() {
    backup = _MockWalletBackupFacade();
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
        await recoverWalletDataAfterSeedRestore(
          backup,
          defaultCreatedWalletIds: {'bitcoin', 'liquid'},
        ),
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
        await recoverWalletDataAfterSeedRestore(
          backup,
          defaultCreatedWalletIds: {'bitcoin', 'liquid'},
        ),
        isFalse,
      );
    },
  );

  test(
    'an optional backup exception cannot invalidate seed recovery',
    () async {
      when(
        () => backup.recover(defaultCreatedWalletIds: {'bitcoin', 'liquid'}),
      ).thenThrow(const FormatException('synthetic unreadable backup'));

      expect(
        await recoverWalletDataAfterSeedRestore(
          backup,
          defaultCreatedWalletIds: {'bitcoin', 'liquid'},
        ),
        isFalse,
      );
    },
  );

  for (final status in WalletBackupRecoveryStatus.values.where(
    (status) =>
        status != WalletBackupRecoveryStatus.noBackup &&
        status != WalletBackupRecoveryStatus.restored,
  )) {
    test('$status is not reported as a complete metadata recovery', () async {
      when(
        () => backup.recover(defaultCreatedWalletIds: {'bitcoin'}),
      ).thenAnswer((_) async => WalletBackupRecoveryResult(status: status));
      expect(
        await recoverWalletDataAfterSeedRestore(
          backup,
          defaultCreatedWalletIds: {'bitcoin'},
        ),
        isFalse,
      );
    });
  }
}
