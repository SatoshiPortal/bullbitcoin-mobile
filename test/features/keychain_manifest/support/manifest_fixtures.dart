import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
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
    bip85DerivationPath: path,
    reservationId: 'btcpay_wallet_seed',
    entryType: 'walletSeed',
    ownerFeature: 'btcpay',
    bip85Application: 39,
    bip85Index: 100,
    createdAt: 1,
    updatedAt: updatedAt,
    materializations: [
      KeychainManifestWallet(
        walletId: walletId,
        entryId: entryId,
        childSeedFingerprint: Fingerprint('fedcba98'),
        network: Network.bitcoinMainnet,
        scriptType: ScriptType.bip84,
        createdAt: 1,
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
    bip85DerivationPath: path,
    reservationId: 'nostr_user_key',
    entryType: 'userGenerated',
    ownerFeature: 'nostr',
    bip85Application: 128002,
    bip85Index: 1,
    createdAt: 1,
    updatedAt: updatedAt,
    materializations: [
      KeychainManifestNostrKey(
        entryId: entryId,
        publicKeyHex: publicKeyHex,
        keyKind: KeychainManifestNostrKeyKind.userGenerated,
        purpose: purpose,
        description: description,
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
    '"inventoryUpdatedAt":2,"entryCount":1,"materializationCount":1,'
    '"entries":[{"entryId":"73c5da0a:39\'/0\'/12\'/100\'",'
    '"bip85DerivationPath":"39\'/0\'/12\'/100\'",'
    '"reservationId":"btcpay_wallet_seed","entryType":"walletSeed",'
    '"ownerFeature":"btcpay","bip85Application":39,"bip85Index":100,'
    '"createdAt":1,"updatedAt":2,"materializations":[{"type":"wallet",'
    '"walletId":"wallet-1","childSeedFingerprint":"fedcba98",'
    '"network":"bitcoinMainnet","scriptType":"bip84","createdAt":1,'
    '"updatedAt":2}]}]}';
