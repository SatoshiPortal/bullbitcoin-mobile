import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_metadata_backup.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_portable_settings_backup.dart';
import 'package:bull_payjoin/bull_payjoin.dart';

const backupFixtureWords =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

WalletBackupSnapshot backupSnapshotFixture(
  BackupCredential credential, {
  bool populated = true,
}) {
  const fingerprint = 'aabbccdd';
  return WalletBackupSnapshot(
    manifest: KeychainManifest(
      sourceFingerprint: fingerprint,
      wallets: populated
          ? [
              BackupWallet(
                reference: 'source-wallet',
                network: Network.bitcoinMainnet,
                publicDescriptor: 'public-fixture-descriptor',
                signers: [],
                isDefault: true,
                isHidden: false,
                label: 'Savings',
                birthday: DateTime.utc(2020),
              ),
            ]
          : [],
      derivations: populated
          ? [
              Bip85DerivationEntity(
                path: "39'/0'/12'/5'",
                xprvFingerprint: fingerprint,
                alias: 'Child',
                status: Bip85Status.revoked,
                application: Bip85Application.bip39,
                index: 5,
              ),
            ]
          : [],
      nostrKeys: populated
          ? [
              NostrKeyRecord(
                parentFingerprint: fingerprint,
                identity: 1,
                publicKey: '3' * 64,
                purpose: 'Messages',
                createdAt: DateTime.utc(2020),
                updatedAt: DateTime.utc(2021),
              ),
            ]
          : [],
      backupIdentities: [
        BackupIdentityRecord(
          parentFingerprint: fingerprint,
          publicKey: credential.artifactPublicKey,
          kind: BackupIdentityKind.artifact,
        ),
        BackupIdentityRecord(
          parentFingerprint: fingerprint,
          publicKey: credential.serverPublicKey,
          kind: BackupIdentityKind.server,
        ),
      ],
    ),
    metadata: WalletMetadataBackup(
      labels: populated
          ? [
              LabelEntity(
                id: 99,
                type: LabelType.transaction,
                label: 'Invoice',
                reference: 'a' * 64,
                origin: 'source-wallet',
              ),
              LabelEntity(
                id: 2,
                type: LabelType.address,
                label: 'Recipient',
                reference: 'address',
                origin: 'payjoin',
              ),
            ]
          : [],
      frozenOutputs: populated
          ? [
              BackupFrozenOutput(
                walletReference: 'source-wallet',
                txId: 'b' * 64,
                vout: 3,
              ),
            ]
          : [],
      settings: WalletPortableSettingsBackup(
        app: PortableAppSettings(
          bitcoinUnit: BitcoinUnit.sats,
          currency: 'CAD',
          language: Language.franceFrench,
          themeMode: AppThemeMode.dark,
          hideAmounts: true,
        ),
        autoSwap: PortableAutoSwapSettings(
          enabled: false,
          balanceThresholdSats: 100000,
          triggerBalanceSats: 200000,
          feeThresholdPercent: 0.5,
          alwaysBlock: true,
          recipientWalletReference: populated ? 'source-wallet' : null,
        ),
        payjoin: PayjoinPolicy.defaults(),
        electrum: [
          for (final network in ElectrumServerNetwork.values)
            PortableElectrumSettings(
              network: network,
              servers: network == ElectrumServerNetwork.bitcoinMainnet
                  ? [
                      PortableElectrumServer(
                        url: 'ssl://electrum.example:50002',
                        priority: 2,
                      ),
                    ]
                  : [],
              validateDomain: true,
              stopGap: 20,
              timeout: 10,
              retry: 3,
            ),
        ],
        mempool: [
          for (final network in MempoolServerNetwork.values)
            PortableMempoolSettings(
              network: network,
              customUrl: 'https://mempool.example',
              useForFeeEstimation: true,
            ),
        ],
      ),
    ),
    vaults: [],
  );
}
