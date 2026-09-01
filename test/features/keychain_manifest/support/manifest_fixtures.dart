import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:primitives/primitives.dart' show Fingerprint;

final manifestFingerprint = Fingerprint('73c5da0a');

KeychainManifestEntry walletManifestEntry({
  String walletId = 'wallet-1',
  int updatedAt = 2,
}) {
  const path = "39'/0'/12'/100'";
  final entryId = '${manifestFingerprint.hex}:$path';
  return KeychainManifestEntry(
    parentFingerprint: manifestFingerprint,
    derivationPath: path,
    createdAt: 1,
    updatedAt: updatedAt,
    materializations: [
      KeychainManifestWallet(
        walletId: walletId,
        entryId: entryId,
        childSeedFingerprint: Fingerprint('fedcba98'),
        network: Network.bitcoinMainnet,
        scriptType: ScriptType.bip84,
        provenance: WalletProvenance.bip85,
        seedPassphraseUsed: false,
        createdAt: 1,
        updatedAt: updatedAt,
      ),
    ],
  );
}

/// A passphrase wallet as the manifest holds it: BIP32 provenance, the
/// combined public descriptor that is its identity, and the label and hint the
/// manifest owns.
KeychainManifestEntry passphraseWalletEntry({
  String walletId = 'passphrase-1',
  String seedFingerprint = '01234567',
  String descriptor = 'wpkh(xpubPassphraseOne/<0;1>/*)',
  String? label = 'Vault',
  String? hint,
  String path = "m/84'/0'/0'",
  int createdAt = 1,
  int updatedAt = 2,
}) {
  final child = Fingerprint(seedFingerprint);
  return KeychainManifestEntry(
    parentFingerprint: manifestFingerprint,
    derivationKind: KeychainManifestDerivationKind.bip32,
    derivationPath: path,
    description: hint,
    createdAt: createdAt,
    updatedAt: updatedAt,
    materializations: [
      KeychainManifestWallet(
        walletId: walletId,
        entryId: KeychainManifestEntry.entryIdFor(
          parentFingerprint: manifestFingerprint,
          derivationKind: KeychainManifestDerivationKind.bip32,
          derivationPath: path,
          seedFingerprint: child,
        ),
        childSeedFingerprint: child,
        network: Network.bitcoinMainnet,
        scriptType: ScriptType.bip84,
        provenance: WalletProvenance.defaultSeedPassphrase,
        seedPassphraseUsed: true,
        descriptor: descriptor,
        label: label,
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
    ],
  );
}

KeychainManifestEntry nostrManifestEntry({
  int identity = 1,
  String publicKeyHex =
      '4fb85384f3a52baadbadc3f9bcb7fd59691e323293160b58959dadd6195c7981',
  String purpose = 'Personal identity',
  String? description,
  int updatedAt = 2,
}) {
  final path = "128002'/$identity'/1'";
  final entryId = '${manifestFingerprint.hex}:$path';
  return KeychainManifestEntry(
    parentFingerprint: manifestFingerprint,
    derivationPath: path,
    description: description,
    createdAt: 1,
    updatedAt: updatedAt,
    materializations: [
      KeychainManifestNostrKey(
        entryId: entryId,
        publicKeyHex: publicKeyHex,
        keyKind: KeychainManifestNostrKeyKind.userGenerated,
        purpose: purpose,
        createdAt: 1,
        updatedAt: updatedAt,
      ),
    ],
  );
}

KeychainManifest manifest({
  List<KeychainManifestEntry>? entries,
  int generatedAt = 3,
}) => KeychainManifest(
  parentFingerprint: manifestFingerprint,
  generatedAt: generatedAt,
  entries: entries ?? [walletManifestEntry()],
);

const canonicalWalletManifest =
    '{"version":1,"parentFingerprint":"73c5da0a","generatedAt":3,'
    '"entries":[{'
    '"derivationKind":"bip85","derivationPath":"39\'/0\'/12\'/100\'",'
    '"createdAt":1,"updatedAt":2,"materializations":[{"type":"wallet",'
    '"walletId":"wallet-1","childSeedFingerprint":"fedcba98",'
    '"network":"bitcoinMainnet","scriptType":"bip84",'
    '"provenance":"bip85","seedPassphraseUsed":false,"createdAt":1,'
    '"updatedAt":2}]}]}';
