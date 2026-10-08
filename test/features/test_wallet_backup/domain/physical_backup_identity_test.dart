import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/onboarding/complete_physical_backup_verification_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Wallets extends Mock implements WalletRepository {}

class _Settings extends Mock implements SettingsRepository {}

Wallet _wallet(String fingerprint, {required bool isDefault}) => Wallet(
  origin: fingerprint,
  masterFingerprint: fingerprint,
  network: Network.bitcoinMainnet,
  xpubFingerprint: fingerprint,
  scriptType: ScriptType.bip84,
  xpub: '',
  externalPublicDescriptor: '',
  internalPublicDescriptor: '',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.zero,
  confirmedBalanceSat: BigInt.zero,
  isDefault: isDefault,
);

void main() {
  test(
    'only rows belonging to the verified imported seed are attested',
    () async {
      final wallets = _Wallets();
      final settings = _Settings();
      final defaultWallet = _wallet('aaaaaaaa', isDefault: true);
      final importedWallet = _wallet('bbbbbbbb', isDefault: false);
      when(() => settings.fetch()).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        ),
      );
      when(
        () => wallets.getWallets(onlyDefaults: false, environment: null),
      ).thenAnswer((_) async => Ok([defaultWallet, importedWallet]));
      when(
        () => wallets.getWallets(
          onlyDefaults: true,
          environment: Environment.mainnet,
        ),
      ).thenAnswer((_) async => Ok([defaultWallet]));
      when(
        () => wallets.updateBackupInfo(
          walletId: any(named: 'walletId'),
          isEncryptedVaultTested: any(named: 'isEncryptedVaultTested'),
          isPhysicalBackupTested: any(named: 'isPhysicalBackupTested'),
          latestEncryptedBackup: any(named: 'latestEncryptedBackup'),
          latestPhysicalBackup: any(named: 'latestPhysicalBackup'),
        ),
      ).thenAnswer((_) async {});

      await CompletePhysicalBackupVerificationUsecase(
        walletRepository: wallets,
        settingsRepository: settings,
      ).execute(masterFingerprint: 'bbbbbbbb');

      verify(
        () => wallets.updateBackupInfo(
          walletId: importedWallet.id,
          isEncryptedVaultTested: false,
          isPhysicalBackupTested: true,
          latestEncryptedBackup: null,
          latestPhysicalBackup: any(named: 'latestPhysicalBackup'),
        ),
      ).called(1);
      verifyNever(
        () => wallets.updateBackupInfo(
          walletId: defaultWallet.id,
          isEncryptedVaultTested: any(named: 'isEncryptedVaultTested'),
          isPhysicalBackupTested: any(named: 'isPhysicalBackupTested'),
          latestEncryptedBackup: any(named: 'latestEncryptedBackup'),
          latestPhysicalBackup: any(named: 'latestPhysicalBackup'),
        ),
      );
    },
  );
}
