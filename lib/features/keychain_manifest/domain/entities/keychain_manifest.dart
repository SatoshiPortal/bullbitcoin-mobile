import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:nostr/nostr.dart' as nostr;
import 'package:primitives/primitives.dart' show Fingerprint;

enum KeychainManifestNostrKeyKind { reserved, userGenerated }

/// How an entry's key material is reached from the parent seed.
///
/// [bip85] and [bip32] are one derivation on the parent seed. [bip85Chain] is
/// two or more BIP85 derivations applied in sequence: every step but the last
/// is a BIP85 application-39 path whose English mnemonic, with an empty
/// passphrase, is the BIP32 root of the next step, and the last step yields
/// the materialization exactly as a single [bip85] entry would. The backup
/// credential is the one chain the app claims: seed → backup words → identity.
enum KeychainManifestDerivationKind { bip85, bip32, bip85Chain }

const _maximumUnixSeconds = 8640000000000;

bool isValidKeychainManifestTimestamp(int value) =>
    value >= 0 && value <= _maximumUnixSeconds;

final class KeychainManifest {
  static const currentVersion = 1;

  final int version;
  final Fingerprint parentFingerprint;
  final int generatedAt;
  final List<KeychainManifestEntry> entries;

  KeychainManifest({
    this.version = currentVersion,
    required this.parentFingerprint,
    required this.generatedAt,
    required Iterable<KeychainManifestEntry> entries,
  }) : entries = List.unmodifiable(entries) {
    if (version != currentVersion ||
        !isValidKeychainManifestTimestamp(generatedAt)) {
      throw ArgumentError('Invalid manifest metadata');
    }
    final entryIds = <String>{};
    final materializationIds = <String>{};
    for (final entry in this.entries) {
      if (entry.parentFingerprint != parentFingerprint ||
          !entryIds.add(entry.entryId)) {
        throw ArgumentError('Invalid or duplicate manifest entry');
      }
      for (final item in entry.materializations) {
        if (!materializationIds.add(item.identity)) {
          throw ArgumentError('Duplicate manifest materialization');
        }
      }
    }
  }

  KeychainManifest canonical() => KeychainManifest(
    version: version,
    parentFingerprint: parentFingerprint,
    generatedAt: generatedAt,
    entries: [...entries]..sort(KeychainManifestEntry.compare),
  );

  Iterable<KeychainManifestWallet> get wallets =>
      entries.expand((entry) => entry.materializations).whereType();

  Iterable<KeychainManifestNostrKey> get nostrKeys =>
      entries.expand((entry) => entry.materializations).whereType();
}

final class KeychainManifestEntry {
  static const maxDescriptionLength = 200;

  /// Joins the steps of a [KeychainManifestDerivationKind.bip85Chain] path in
  /// its one canonical string form, `39'/0'/12'/104' > 128002'/100'/1'`.
  static const chainSeparator = ' > ';
  static const maxChainSteps = 4;

  final Fingerprint parentFingerprint;
  final KeychainManifestDerivationKind derivationKind;
  final String derivationPath;
  final String? description;
  final int createdAt;
  final int updatedAt;
  final List<KeychainManifestMaterialization> materializations;

  KeychainManifestEntry({
    required this.parentFingerprint,
    this.derivationKind = KeychainManifestDerivationKind.bip85,
    required String derivationPath,
    String? description,
    required this.createdAt,
    required this.updatedAt,
    required Iterable<KeychainManifestMaterialization> materializations,
  }) : derivationPath = canonicalPath(derivationKind, derivationPath),
       description = _optional(description),
       materializations = List.unmodifiable(materializations) {
    if ((this.description?.length ?? 0) > maxDescriptionLength ||
        (this.description != null &&
            KeychainManifestNostrKey.hasControlCharacter(this.description!)) ||
        !isValidKeychainManifestTimestamp(createdAt) ||
        !isValidKeychainManifestTimestamp(updatedAt) ||
        updatedAt < createdAt ||
        this.materializations.isEmpty ||
        this.materializations.length > 8 ||
        this.materializations.any((item) => item.entryId != entryId) ||
        (derivationKind == KeychainManifestDerivationKind.bip32 &&
            (this.materializations.length != 1 ||
                this.materializations.single is! KeychainManifestWallet)) ||
        // A chain ends in a key, never a wallet: the intermediate mnemonic is
        // a root for further derivation, not a wallet seed.
        (derivationKind == KeychainManifestDerivationKind.bip85Chain &&
            (this.materializations.length != 1 ||
                this.materializations.single is! KeychainManifestNostrKey))) {
      throw ArgumentError('Invalid manifest entry');
    }
  }

  String get entryId => entryIdFor(
    parentFingerprint: parentFingerprint,
    derivationKind: derivationKind,
    derivationPath: derivationPath,
    seedFingerprint: derivationKind == KeychainManifestDerivationKind.bip32
        ? (materializations.single as KeychainManifestWallet)
              .childSeedFingerprint
        : null,
    network: derivationKind == KeychainManifestDerivationKind.bip32
        ? (materializations.single as KeychainManifestWallet).network
        : null,
  );

  /// A key the app reserved for itself, which the user did not create and
  /// cannot delete.
  bool get isSystemNostrKey {
    final key = materializations.singleOrNull;
    return key is KeychainManifestNostrKey &&
        key.keyKind == KeychainManifestNostrKeyKind.reserved;
  }

  static String entryIdFor({
    required Fingerprint parentFingerprint,
    required KeychainManifestDerivationKind derivationKind,
    required String derivationPath,
    Fingerprint? seedFingerprint,
    Network? network,
  }) {
    final path = canonicalPath(derivationKind, derivationPath);
    if (derivationKind != KeychainManifestDerivationKind.bip32) {
      return '${parentFingerprint.hex}:$path';
    }
    if (seedFingerprint == null || network == null) {
      throw ArgumentError('BIP32 manifest identity requires seed and network');
    }
    // Bitcoin and Liquid testnet share coin type 1 and the same account path.
    return '${parentFingerprint.hex}:${seedFingerprint.hex}:${network.name}:$path';
  }

  static String canonicalPath(
    KeychainManifestDerivationKind kind,
    String value,
  ) => _canonicalPath(kind, value);

  String get bip85DerivationPath {
    if (derivationKind != KeychainManifestDerivationKind.bip85) {
      throw StateError('Manifest entry is not a BIP85 derivation');
    }
    return derivationPath;
  }

  /// The ordered BIP85 steps of a chain entry, first applied to the parent
  /// seed and each following one to the previous step's mnemonic root.
  List<String> get bip85ChainSteps {
    if (derivationKind != KeychainManifestDerivationKind.bip85Chain) {
      throw StateError('Manifest entry is not a BIP85 chain');
    }
    return chainSteps(derivationPath);
  }

  static List<String> chainSteps(String canonicalChainPath) =>
      List.unmodifiable(canonicalChainPath.split(chainSeparator));

  static String chainPath(Iterable<String> steps) => canonicalPath(
    KeychainManifestDerivationKind.bip85Chain,
    steps.join(chainSeparator),
  );

  KeychainManifestEntry withMaterializations(
    Iterable<KeychainManifestMaterialization> items, {
    int? createdAt,
    int? updatedAt,
  }) => KeychainManifestEntry(
    parentFingerprint: parentFingerprint,
    derivationKind: derivationKind,
    derivationPath: derivationPath,
    description: description,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    materializations: items,
  );

  static int compare(KeychainManifestEntry left, KeychainManifestEntry right) {
    final byKind = left.derivationKind.index.compareTo(
      right.derivationKind.index,
    );
    if (byKind != 0) return byKind;
    final byPath = left.derivationPath.compareTo(right.derivationPath);
    return byPath != 0 ? byPath : left.entryId.compareTo(right.entryId);
  }
}

sealed class KeychainManifestMaterialization {
  String get entryId;
  int get createdAt;
  int get updatedAt;
  String get identity;
}

final class KeychainManifestWallet extends KeychainManifestMaterialization {
  static const maxDescriptorLength = 512;
  static const maxLabelLength = 50;

  final String walletId;
  @override
  final String entryId;
  final Fingerprint childSeedFingerprint;
  final Network network;
  final ScriptType scriptType;
  final WalletProvenance provenance;
  final bool? seedPassphraseUsed;
  final String? descriptor;
  final String? label;
  @override
  final int createdAt;
  @override
  final int updatedAt;

  KeychainManifestWallet({
    required String walletId,
    required String entryId,
    required this.childSeedFingerprint,
    required this.network,
    required this.scriptType,
    required this.provenance,
    required this.seedPassphraseUsed,
    this.descriptor,
    String? label,
    required this.createdAt,
    required this.updatedAt,
  }) : walletId = _required(walletId),
       entryId = _required(entryId),
       label = _optional(label) {
    if (!isValid(
      walletId: this.walletId,
      entryId: this.entryId,
      provenance: provenance,
      descriptor: descriptor,
      label: this.label,
      createdAt: createdAt,
      updatedAt: updatedAt,
    )) {
      throw ArgumentError('Invalid wallet materialization');
    }
  }

  static bool isValid({
    required String walletId,
    required String entryId,
    required WalletProvenance provenance,
    required String? descriptor,
    required String? label,
    required int createdAt,
    required int updatedAt,
  }) =>
      _tryRequired(walletId) != null &&
      _tryRequired(entryId) != null &&
      isValidKeychainManifestTimestamp(createdAt) &&
      isValidKeychainManifestTimestamp(updatedAt) &&
      updatedAt >= createdAt &&
      (label == null ||
          (label.length <= maxLabelLength &&
              !KeychainManifestNostrKey.hasControlCharacter(label))) &&
      !provenance.backedUpAsDefinition &&
      (provenance != WalletProvenance.defaultSeedPassphrase ||
          (descriptor != null &&
              descriptor.trim().isNotEmpty &&
              descriptor.length <= maxDescriptorLength));

  @override
  String get identity => 'wallet:$walletId';

  KeychainManifestWallet withWalletId(String walletId) =>
      KeychainManifestWallet(
        walletId: walletId,
        entryId: entryId,
        childSeedFingerprint: childSeedFingerprint,
        network: network,
        scriptType: scriptType,
        provenance: provenance,
        seedPassphraseUsed: seedPassphraseUsed,
        descriptor: descriptor,
        label: label,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

final class KeychainManifestNostrKey extends KeychainManifestMaterialization {
  static const maxPurposeLength = 80;
  static final _publicKeyPattern = RegExp(r'^[0-9a-f]{64}$');
  static final _controlPattern = RegExp(r'[\u0000-\u001F\u007F]');

  @override
  final String entryId;
  final String publicKeyHex;
  final KeychainManifestNostrKeyKind keyKind;
  final String purpose;
  @override
  final int createdAt;
  @override
  final int updatedAt;

  KeychainManifestNostrKey({
    required String entryId,
    required String publicKeyHex,
    required this.keyKind,
    required String purpose,
    required this.createdAt,
    required this.updatedAt,
  }) : entryId = _required(entryId),
       publicKeyHex = publicKeyHex.toLowerCase(),
       purpose = purpose.trim() {
    if (!isValid(
      entryId: this.entryId,
      publicKeyHex: this.publicKeyHex,
      purpose: this.purpose,
      createdAt: createdAt,
      updatedAt: updatedAt,
    )) {
      throw ArgumentError('Invalid Nostr materialization');
    }
  }

  static bool isValid({
    required String entryId,
    required String publicKeyHex,
    required String purpose,
    required int createdAt,
    required int updatedAt,
  }) =>
      _tryRequired(entryId) != null &&
      _publicKeyPattern.hasMatch(publicKeyHex.toLowerCase()) &&
      tryNormalizePurpose(purpose) != null &&
      isValidKeychainManifestTimestamp(createdAt) &&
      isValidKeychainManifestTimestamp(updatedAt) &&
      updatedAt >= createdAt;

  static String? tryNormalizePurpose(String purpose) {
    final normalizedPurpose = purpose.trim();
    if (normalizedPurpose.isEmpty ||
        normalizedPurpose.length > maxPurposeLength ||
        _controlPattern.hasMatch(normalizedPurpose)) {
      return null;
    }
    return normalizedPurpose;
  }

  static bool hasControlCharacter(String value) =>
      _controlPattern.hasMatch(value);

  @override
  String get identity => 'nostr:$entryId';

  late final String npub = nostr.Bech32Entity.encode(
    prefix: nostr.Nip19Prefix.npub,
    data: publicKeyHex,
  );
}

String _required(String value) {
  final result = _tryRequired(value);
  if (result == null) {
    throw ArgumentError('Required manifest text is invalid');
  }
  return result;
}

String? _tryRequired(String value) {
  final result = value.trim();
  return result.isEmpty || result.length > 512 ? null : result;
}

String? _optional(String? value) {
  final result = value?.trim();
  return result == null || result.isEmpty ? null : result;
}

String _canonicalPath(KeychainManifestDerivationKind kind, String value) {
  if (kind == KeychainManifestDerivationKind.bip85Chain) {
    final steps = value
        .split('>')
        .map(
          (step) => _canonicalPath(KeychainManifestDerivationKind.bip85, step),
        )
        .toList(growable: false);
    if (steps.length < 2 ||
        steps.length > KeychainManifestEntry.maxChainSteps) {
      throw ArgumentError('Invalid BIP85 chain');
    }
    // Every step but the last must produce an English BIP39 mnemonic, which is
    // what the next step derives from: BIP85 application 39, language 0.
    if (steps
        .take(steps.length - 1)
        .any((step) => !step.startsWith("39'/0'/"))) {
      throw ArgumentError('Invalid BIP85 chain');
    }
    return steps.join(KeychainManifestEntry.chainSeparator);
  }
  final trimmed = value.trim();
  final hasRoot = trimmed.startsWith('m/');
  if (kind == KeychainManifestDerivationKind.bip32 && !hasRoot) {
    throw ArgumentError('Invalid BIP32 path');
  }
  if (kind == KeychainManifestDerivationKind.bip85 && hasRoot) {
    throw ArgumentError('Invalid BIP85 path');
  }
  final parts = (hasRoot ? trimmed.substring(2) : trimmed).split('/');
  if (parts.length < 2) throw ArgumentError('Invalid derivation path');
  final numbers = parts.map(_pathNumber).toList(growable: false);
  final path = numbers.map((number) => "$number'").join('/');
  return hasRoot ? 'm/$path' : path;
}

int _pathNumber(String segment) {
  if (!RegExp(r"^(0|[1-9][0-9]*)(?:'|h|H)$").hasMatch(segment)) {
    throw ArgumentError('Invalid derivation path');
  }
  final value = int.parse(segment.substring(0, segment.length - 1));
  if (value > 0x7fffffff) throw ArgumentError('Invalid derivation path');
  return value;
}
