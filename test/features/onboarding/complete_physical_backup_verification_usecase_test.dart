import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/check_physical_backup_verified_usecase.dart';
import 'package:bb_mobile/features/onboarding/complete_physical_backup_verification_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockGetWalletsUsecase extends Mock implements GetWalletsUsecase {}

void main() {
  test(
    'persists verification only for wallets using the requested seed',
    () async {
      final walletRepository = _MockWalletRepository();
      final settingsRepository = _MockSettingsRepository();
      final requested = _wallet(origin: 'requested', fingerprint: 'deadbeef');
      final other = _wallet(origin: 'other', fingerprint: 'cafebabe');
      final shared = requested.copyWith(
        origin: 'shared',
        signers: [...requested.signers, ...other.signers],
      );
      var wallets = [requested, other, shared];
      when(
        () => walletRepository.getWallets(onlyBitcoin: true),
      ).thenAnswer((_) async => wallets);
      when(
        () => walletRepository.updateBackupInfo(
          walletId: any(named: 'walletId'),
          isEncryptedVaultTested: any(named: 'isEncryptedVaultTested'),
          isPhysicalBackupTested: any(named: 'isPhysicalBackupTested'),
          latestEncryptedBackup: any(named: 'latestEncryptedBackup'),
          latestPhysicalBackup: any(named: 'latestPhysicalBackup'),
        ),
      ).thenAnswer((invocation) async {
        wallets = [
          for (final wallet in wallets)
            wallet.id == invocation.namedArguments[#walletId]
                ? wallet.copyWith(
                    isPhysicalBackupTested:
                        invocation.namedArguments[#isPhysicalBackupTested]
                            as bool,
                  )
                : wallet,
        ];
      });
      final usecase = CompletePhysicalBackupVerificationUsecase(
        walletRepository: walletRepository,
        settingsRepository: settingsRepository,
      );

      await usecase.execute(fingerprint: 'DEADBEEF');

      final captured = verify(
        () => walletRepository.updateBackupInfo(
          walletId: captureAny(named: 'walletId'),
          isEncryptedVaultTested: false,
          isPhysicalBackupTested: true,
          latestEncryptedBackup: null,
          latestPhysicalBackup: any(named: 'latestPhysicalBackup'),
        ),
      ).captured;
      expect(captured, ['requested']);
      final getWallets = _MockGetWalletsUsecase();
      when(
        () => getWallets.execute(onlyBitcoin: true),
      ).thenAnswer((_) async => wallets);
      final check = CheckPhysicalBackupVerifiedUsecase(getWallets);
      expect(await check.execute('deadbeef'), isTrue);
      expect(await check.execute('cafebabe'), isFalse);
      wallets = [shared.copyWith(isPhysicalBackupTested: true)];
      expect(await check.execute('cafebabe'), isFalse);
    },
  );
}

Wallet _wallet({required String origin, required String fingerprint}) => Wallet(
  origin: origin,
  network: Network.bitcoinMainnet,
  signers: [
    WalletSigner.single(
      masterFingerprint: fingerprint,
      xpubFingerprint: '01234567',
      xpub: 'xpub-$origin',
      derivationPath: "m/84'/0'/0'",
      signer: SignerEntity.local,
      signerDevice: null,
    ),
  ],
  scriptType: ScriptType.bip84,
  publicDescriptor: 'wpkh(xpub-$origin/<0;1>/*)',
  balanceSat: BigInt.zero,
);
