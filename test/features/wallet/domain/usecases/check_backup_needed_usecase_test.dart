import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_backup_needed_usecase.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _GetWallets extends Mock implements GetWalletsUsecase {}

class _Wallet extends Mock implements Wallet {}

void main() {
  late _GetWallets getWallets;
  late _Wallet wallet;
  late RecoverBullStatus recoverBullStatus;
  late CheckBackupNeededUsecase usecase;

  setUp(() {
    getWallets = _GetWallets();
    wallet = _Wallet();
    recoverBullStatus = const RecoverBullStatus.initial();
    usecase = CheckBackupNeededUsecase(
      getWallets,
      () async => recoverBullStatus,
    );
    when(
      () => getWallets.execute(onlyDefaults: true),
    ).thenAnswer((_) async => [wallet]);
    when(() => wallet.isPhysicalBackupTested).thenReturn(false);
  });

  test(
    'verified package backup satisfies the encrypted backup requirement',
    () async {
      recoverBullStatus = RecoverBullStatus(
        lastVerifiedEncryptedBackupAt: DateTime(2026),
      );

      expect(await usecase.execute(), isFalse);
    },
  );

  test('fresh package status ignores legacy encrypted metadata', () async {
    recoverBullStatus = const RecoverBullStatus.initial();
    when(() => wallet.isEncryptedVaultTested).thenReturn(true);
    when(() => wallet.latestEncryptedBackup).thenReturn(DateTime(2026));

    expect(await usecase.execute(), isTrue);
    verifyNever(() => wallet.isEncryptedVaultTested);
    verifyNever(() => wallet.latestEncryptedBackup);
  });

  test(
    'physical backup satisfies the requirement without package verification',
    () async {
      recoverBullStatus = const RecoverBullStatus.initial();
      when(() => wallet.isPhysicalBackupTested).thenReturn(true);

      expect(await usecase.execute(), isFalse);
    },
  );

  test(
    'unavailable package status conservatively requires a physical backup',
    () async {
      recoverBullStatus = const RecoverBullStatus.unavailable();

      expect(await usecase.execute(), isTrue);
    },
  );
}
