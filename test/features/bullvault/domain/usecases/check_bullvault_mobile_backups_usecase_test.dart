import 'package:bb_mobile/features/bullvault/domain/usecases/check_bullvault_mobile_backups_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bb_mobile/features/test_wallet_backup/public/test_wallet_backup_facade.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart' show Network;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTestWalletBackupFacade extends Mock
    implements TestWalletBackupFacade {}

void main() {
  test(
    'reports both backup methods for the exact Bull seed and network',
    () async {
      final physical = _MockTestWalletBackupFacade();
      when(
        () => physical.isPhysicalBackupVerified('deadbeef'),
      ).thenAnswer((_) async => true);
      for (final verifiedAt in [null, DateTime.utc(2026)]) {
        final usecase = CheckBullVaultMobileBackupsUsecase(physical, (
          selected,
        ) async {
          expect(selected.fingerprint.hex, 'deadbeef');
          expect(selected.network, BitcoinNetwork.testnet);
          return Ok(BackupStatus(verifiedAt: verifiedAt));
        });
        final result = await usecase.execute(
          'deadbeef',
          network: Network.bitcoinTestnet,
        );
        expect((result as Ok).value, (
          physical: true,
          recoverBull: verifiedAt != null,
        ));
      }
    },
  );

  test(
    'reports unavailable certification instead of claiming no backup',
    () async {
      final physical = _MockTestWalletBackupFacade();
      when(
        () => physical.isPhysicalBackupVerified('deadbeef'),
      ).thenAnswer((_) async => true);
      final usecase = CheckBullVaultMobileBackupsUsecase(
        physical,
        (_) async => const Err(RecoverBullJournalFailure()),
      );
      final result = await usecase.execute(
        'deadbeef',
        network: Network.bitcoinTestnet,
      );
      expect((result as Err).failure, isA<BullVaultBackupStatusFailure>());
    },
  );
}
