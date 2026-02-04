import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

class WalletMetadataDumpUsecase {
  final SettingsRepository _settingsRepository;
  final WalletRepository _walletRepository;

  WalletMetadataDumpUsecase({
    required SettingsRepository settingsRepository,
    required WalletRepository walletRepository,
  })  : _settingsRepository = settingsRepository,
        _walletRepository = walletRepository;

  Future<void> execute() async {
    try {
      final settings = await _settingsRepository.fetch();
      final environment = settings.environment;
      final defaultWallets = await _walletRepository.getWallets(
        onlyDefaults: true,
        environment: environment,
      );

      if (defaultWallets.isEmpty) {
        log.info('WALLET_METADATA_DUMP: No default wallets found');
        return;
      }

      log.info('WALLET_METADATA_DUMP: Found ${defaultWallets.length} default wallet(s)');

      for (final wallet in defaultWallets) {
        log.info('''
WALLET_METADATA_DUMP: ========================================
  ID: ${wallet.id}
  Label: ${wallet.label ?? 'N/A'}
  Network: ${wallet.networkString}
  Is Default: ${wallet.isDefault}
  Master Fingerprint: ${wallet.masterFingerprint}
  XPub Fingerprint: ${wallet.xpubFingerprint}
  Script Type: ${wallet.scriptType.name}
  Address Type: ${wallet.addressType}
  Derivation Path: ${wallet.derivationPath}
  XPub: ${wallet.xpub}
  External Public Descriptor: ${wallet.externalPublicDescriptor}
  Internal Public Descriptor: ${wallet.internalPublicDescriptor}
  Signer: ${wallet.signer.name}
  Signer Device: ${wallet.signerDevice?.name ?? 'N/A'}
  Balance (sats): ${wallet.balanceSat}
  Is Watch Only: ${wallet.isWatchOnly}
  Is Watch Signer: ${wallet.isWatchSigner}
  Signs Locally: ${wallet.signsLocally}
  Signs Remotely: ${wallet.signsRemotely}
  Is Encrypted Vault Tested: ${wallet.isEncryptedVaultTested}
  Is Physical Backup Tested: ${wallet.isPhysicalBackupTested}
  Latest Encrypted Backup: ${wallet.latestEncryptedBackup?.toIso8601String() ?? 'N/A'}
  Latest Physical Backup: ${wallet.latestPhysicalBackup?.toIso8601String() ?? 'N/A'}
WALLET_METADATA_DUMP: ========================================''');
      }
    } catch (e) {
      log.severe(
        message: 'WALLET_METADATA_DUMP: Failed to dump wallet metadata',
        error: e,
        trace: StackTrace.current,
      );
    }
  }
}
