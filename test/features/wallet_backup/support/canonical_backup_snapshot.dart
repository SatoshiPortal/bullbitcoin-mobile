import 'package:bb_mobile/core/bip85/domain/bip85_reservations.dart';
import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/frozen_wallet_outpoint.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_definition.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_preferences.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/features/keychain_manifest/data/models/keychain_manifest_file_model.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/parse_keychain_manifest_file_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/wallet_backup/data/models/wallet_backup_snapshot_model.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_snapshot.dart';
import 'package:primitives/primitives.dart' show Fingerprint;

import '../metadata/support/portable_settings_fixture.dart';

/// The seed the golden fixtures belong to.
final canonicalParentFingerprint = Fingerprint('deadbeef');

const canonicalCreatedAt = 1788192000;
const canonicalExternalDescriptor =
    'wpkh([86241f88/84h/0h/0h]xpub6DJwRncrB8eNrzUq8XxgjwCZsEeWP8FeqBJbJQZ8Jfu'
    'DwLdAzyjhHiHJieNuar1wjQTyihhMWtaKGE4DUd8uBgtyrNJqF5drwbNVUqb83b7/<0;1>/*)'
    '#n8txaeah';
const canonicalPassphraseDescriptor =
    'wpkh([a1b2c3d4/84h/0h/0h]xpub6DJwRncrB8eNrzUq8XxgjwCZsEeWP8FeqBJbJQZ8Jfu'
    'DwLdAzyjhHiHJieNuar1wjQTyihhMWtaKGE4DUd8uBgtyrNJqF5drwbNVUqb83b7/<0;1>/*)';

/// A codec wired the way the app wires it: the manifest section is encoded and
/// decoded by the keychain manifest's own codec.
WalletBackupSnapshotCodec canonicalCodec() {
  const manifest = KeychainManifestFileCodec();
  final parse = ParseKeychainManifestFileUsecase(manifest.decode);
  return WalletBackupSnapshotCodec(
    encodeManifest: manifest.encode,
    decodeManifest: parse.execute,
  );
}

/// Every section populated, including a passphrase wallet with a label and a
/// hint, and one reserved Nostr identity.
WalletBackupSnapshot canonicalFullSnapshot() => WalletBackupSnapshot(
  parentFingerprint: canonicalParentFingerprint,
  createdAt: canonicalCreatedAt,
  recoveryManifest: KeychainManifest(
    parentFingerprint: canonicalParentFingerprint,
    generatedAt: 1788191000,
    entries: [
      _passphraseEntry(),
      KeychainManifestEntry(
        parentFingerprint: canonicalParentFingerprint,
        derivationPath: Bip85Reservations.nostrWalletBackupKey.path,
        createdAt: 1788100000,
        updatedAt: 1788100000,
        materializations: [
          KeychainManifestNostrKey(
            entryId: KeychainManifestEntry.entryIdFor(
              parentFingerprint: canonicalParentFingerprint,
              derivationKind: KeychainManifestDerivationKind.bip85,
              derivationPath: Bip85Reservations.nostrWalletBackupKey.path,
            ),
            publicKeyHex:
                '9c1b0e6a8f2d4c3b5a6978e0f1d2c3b4a596877665544332211000ffeeddccbb',
            keyKind: KeychainManifestNostrKeyKind.reserved,
            purpose: 'Wallet backup',
            createdAt: 1788100000,
            updatedAt: 1788100000,
          ),
        ],
      ),
    ],
  ),
  externalWalletDefinitions: [
    WalletDefinition(
      walletRef: 'external-cold-wallet',
      network: Network.bitcoinMainnet,
      descriptor: canonicalExternalDescriptor,
      signerDevice: SignerDeviceEntity.coldcardQ,
      birthday: DateTime.fromMillisecondsSinceEpoch(
        1788000000 * 1000,
        isUtc: true,
      ),
      provenance: WalletProvenance.externalSigner,
    ),
  ],
  metadata: WalletMetadataSnapshot(
    labels: const [
      WalletMetadataLabel(
        type: LabelType.transaction,
        reference:
            '1111111111111111111111111111111111111111111111111111111111111111',
        label: 'Coffee',
        origin: 'bull',
      ),
    ],
    frozenOutpoints: [
      FrozenWalletOutpoint(
        walletId: 'wallet-passphrase-1',
        txId:
            '2222222222222222222222222222222222222222222222222222222222222222',
        vout: 1,
      ),
    ],
    walletPreferences: [
      WalletPreferences(
        walletRef: 'wallet-passphrase-1',
        label: 'Vacation',
        hideOnHome: false,
      ),
    ],
    settings: portableSettingsFixture(),
  ),
);

/// The manifest alone: the definitions and metadata sections are left out.
WalletBackupSnapshot canonicalMinimalSnapshot() => WalletBackupSnapshot(
  parentFingerprint: canonicalParentFingerprint,
  createdAt: canonicalCreatedAt,
  recoveryManifest: KeychainManifest(
    parentFingerprint: canonicalParentFingerprint,
    generatedAt: 1788191000,
    entries: [_passphraseEntry()],
  ),
);

KeychainManifestEntry _passphraseEntry() => KeychainManifestEntry(
  parentFingerprint: canonicalParentFingerprint,
  derivationKind: KeychainManifestDerivationKind.bip32,
  derivationPath: "m/84'/0'/0'",
  description: 'Second word is the city we met in',
  createdAt: 1788100000,
  updatedAt: 1788150000,
  materializations: [
    KeychainManifestWallet(
      walletId: 'wallet-passphrase-1',
      entryId: KeychainManifestEntry.entryIdFor(
        parentFingerprint: canonicalParentFingerprint,
        derivationKind: KeychainManifestDerivationKind.bip32,
        derivationPath: "m/84'/0'/0'",
        seedFingerprint: Fingerprint('a1b2c3d4'),
      ),
      childSeedFingerprint: Fingerprint('a1b2c3d4'),
      network: Network.bitcoinMainnet,
      scriptType: ScriptType.bip84,
      provenance: WalletProvenance.defaultSeedPassphrase,
      seedPassphraseUsed: true,
      descriptor: canonicalPassphraseDescriptor,
      label: 'Vacation',
      createdAt: 1788100000,
      updatedAt: 1788150000,
    ),
  ],
);
