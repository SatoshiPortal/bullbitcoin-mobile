import 'package:bb_mobile/core/utils/nostr_bech32.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:convert/convert.dart';
import 'package:primitives/primitives.dart' show Fingerprint;

enum KeychainManifestNostrKeyKind { reserved, userGenerated }

enum KeychainManifestDerivationKind { bip85, bip32 }

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
                this.materializations.single is! KeychainManifestWallet))) {
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
  );

  static String entryIdFor({
    required Fingerprint parentFingerprint,
    required KeychainManifestDerivationKind derivationKind,
    required String derivationPath,
    Fingerprint? seedFingerprint,
  }) {
    final path = canonicalPath(derivationKind, derivationPath);
    return derivationKind == KeychainManifestDerivationKind.bip85
        ? '${parentFingerprint.hex}:$path'
        : '${parentFingerprint.hex}:${seedFingerprint!.hex}:$path';
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
      provenance != WalletProvenance.watchOnly &&
      provenance != WalletProvenance.externalSigner &&
      (provenance != WalletProvenance.defaultSeedPassphrase ||
          (descriptor != null &&
              descriptor.trim().isNotEmpty &&
              descriptor.length <= maxDescriptorLength));

  @override
  String get identity => 'wallet:$walletId';
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

  late final String npub = NostrBech32.npub(hex.decode(publicKeyHex));
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
