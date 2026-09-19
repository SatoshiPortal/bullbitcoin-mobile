import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_ciphertext.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import '../bullvault/bullvault_test_fixture.dart';
import '../wallet_backup/backup_snapshot_fixture.dart';

VaultBackupRecovery vaultRecoveryFixture({bool partial = false}) {
  final credential = BackupCredential.fromWords(backupFixtureWords);
  final base = backupSnapshotFixture(credential, populated: false);
  final vault = testBullVaultCreateResult(walletId: 'source-vault');
  return VaultBackupRecovery(
    inspection: WalletBackupInspection(
      identity: credential.serverPublicKey,
      head: WalletBackupRemoteHead(
        generation: 1,
        etag: 'a' * 64,
        ciphertext: WalletBackupCiphertext(List.filled(64, 1)),
      ),
      snapshot: WalletBackupSnapshot(
        manifest: KeychainManifest(
          sourceFingerprint: base.manifest.sourceFingerprint,
          wallets: [
            BackupWallet(
              reference: 'source-vault',
              network: vault.record.recoveryPackage.policy.network,
              publicDescriptor: vault.record.recoveryPackage.policy.descriptor,
              signers: [],
              isDefault: false,
              isHidden: false,
              label: 'Family vault',
            ),
          ],
          derivations: [],
          nostrKeys: [],
          backupIdentities: base.manifest.backupIdentities,
        ),
        metadata: base.metadata,
        vaults: [
          BullVaultBackupEntry(
            reference: 'source-vault',
            status: vault.record.status,
            recoveryPackage: vault.record.recoveryPackage,
          ),
        ],
      ),
    ),
    wallets: WalletInventoryRecovery(
      walletReferences: partial ? {} : {'source-vault': 'actual-target'},
      failedReferences: partial ? ['source-vault'] : [],
    ),
  );
}
