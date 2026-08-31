import 'package:bb_mobile/features/bullvault/domain/usecases/check_bullvault_mobile_backups_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/recoverbull/public/recoverbull_facade.dart';
import 'package:bb_mobile/features/test_wallet_backup/public/test_wallet_backup_facade.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTestWalletBackupFacade extends Mock
    implements TestWalletBackupFacade {}

class _MockRecoverBullFacade extends Mock implements RecoverBullFacade {}

void main() {
  test('reports both backup methods for the exact Bull seed', () async {
    final physical = _MockTestWalletBackupFacade();
    final recoverBull = _MockRecoverBullFacade();
    when(
      () => physical.isPhysicalBackupVerified('deadbeef'),
    ).thenAnswer((_) async => true);
    when(
      () => recoverBull.hasTestedBackup('deadbeef'),
    ).thenAnswer((_) async => false);
    final usecase = CheckBullVaultMobileBackupsUsecase(physical, recoverBull);

    final result = await usecase.execute('deadbeef');

    switch (result) {
      case Ok(:final value):
        expect(value.physical, isTrue);
        expect(value.recoverBull, isFalse);
      case Err():
        fail('Expected backup status');
    }
  });

  test(
    'reports an unavailable backup status instead of claiming none',
    () async {
      final physical = _MockTestWalletBackupFacade();
      final recoverBull = _MockRecoverBullFacade();
      when(
        () => physical.isPhysicalBackupVerified('deadbeef'),
      ).thenThrow(Exception('storage unavailable'));
      final usecase = CheckBullVaultMobileBackupsUsecase(physical, recoverBull);

      final result = await usecase.execute('deadbeef');

      switch (result) {
        case Ok():
          fail('Expected backup status failure');
        case Err(:final failure):
          expect(failure, isA<BullVaultBackupStatusFailure>());
      }
      verifyNever(() => recoverBull.hasTestedBackup(any()));
    },
  );
}
