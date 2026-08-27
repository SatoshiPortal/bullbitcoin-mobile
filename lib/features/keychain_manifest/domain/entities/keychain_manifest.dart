import 'package:bb_mobile/core/utils/nostr_bech32.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:convert/convert.dart';
import 'package:primitives/primitives.dart' show Fingerprint;

enum KeychainManifestNostrKeyKind { reserved, userGenerated }

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
    if (version != currentVersion || generatedAt < 0) {
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

  int get entryCount => entries.length;
  int get materializationCount =>
      entries.fold(0, (count, entry) => count + entry.materializations.length);
  int get inventoryUpdatedAt => entries.fold(0, (latest, entry) {
    var result = entry.updatedAt > latest ? entry.updatedAt : latest;
    for (final item in entry.materializations) {
      if (item.updatedAt > result) result = item.updatedAt;
    }
    return result;
  });

  KeychainManifest canonical() => KeychainManifest(
    version: version,
    parentFingerprint: parentFingerprint,
    generatedAt: generatedAt,
    entries: [...entries]..sort(KeychainManifestEntry.compare),
  );
}

final class KeychainManifestEntry {
  final Fingerprint parentFingerprint;
  final String bip85DerivationPath;
  final String reservationId;
  final String entryType;
  final String ownerFeature;
  final int bip85Application;
  final int bip85Index;
  final int createdAt;
  final int updatedAt;
  final List<KeychainManifestMaterialization> materializations;

  KeychainManifestEntry({
    required this.parentFingerprint,
    required String bip85DerivationPath,
    required String reservationId,
    required String entryType,
    required String ownerFeature,
    required this.bip85Application,
    required this.bip85Index,
    required this.createdAt,
    required this.updatedAt,
    required Iterable<KeychainManifestMaterialization> materializations,
  }) : bip85DerivationPath = _canonicalPath(bip85DerivationPath),
       reservationId = _required(reservationId),
       entryType = _required(entryType),
       ownerFeature = _required(ownerFeature),
       materializations = List.unmodifiable(materializations) {
    final parts = this.bip85DerivationPath.split('/');
    if (bip85Application != _pathNumber(parts.first) ||
        bip85Index != _pathNumber(parts.last) ||
        createdAt < 0 ||
        updatedAt < 0 ||
        this.materializations.isEmpty ||
        this.materializations.length > 8 ||
        this.materializations.any((item) => item.entryId != entryId)) {
      throw ArgumentError('Invalid manifest entry');
    }
  }

  String get entryId => '${parentFingerprint.hex}:$bip85DerivationPath';

  KeychainManifestEntry withMaterializations(
    Iterable<KeychainManifestMaterialization> items, {
    int? createdAt,
    int? updatedAt,
  }) => KeychainManifestEntry(
    parentFingerprint: parentFingerprint,
    bip85DerivationPath: bip85DerivationPath,
    reservationId: reservationId,
    entryType: entryType,
    ownerFeature: ownerFeature,
    bip85Application: bip85Application,
    bip85Index: bip85Index,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    materializations: items,
  );

  bool hasSameMetadata(KeychainManifestEntry other) =>
      entryId == other.entryId &&
      reservationId == other.reservationId &&
      entryType == other.entryType &&
      ownerFeature == other.ownerFeature &&
      bip85Application == other.bip85Application &&
      bip85Index == other.bip85Index;

  static int compare(KeychainManifestEntry left, KeychainManifestEntry right) {
    final byPath = left.bip85DerivationPath.compareTo(
      right.bip85DerivationPath,
    );
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
  final String walletId;
  @override
  final String entryId;
  final Fingerprint childSeedFingerprint;
  final Network network;
  final ScriptType scriptType;
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
    required this.createdAt,
    required this.updatedAt,
  }) : walletId = _required(walletId),
       entryId = _required(entryId) {
    if (createdAt < 0 || updatedAt < 0) {
      throw ArgumentError('Invalid wallet materialization');
    }
  }

  @override
  String get identity => 'wallet:$walletId';
}

final class KeychainManifestNostrKey extends KeychainManifestMaterialization {
  static const maxPurposeLength = 80;
  static const maxDescriptionLength = 200;
  static final _publicKeyPattern = RegExp(r'^[0-9a-f]{64}$');
  static final _controlPattern = RegExp(r'[\u0000-\u001F\u007F]');

  @override
  final String entryId;
  final String publicKeyHex;
  final KeychainManifestNostrKeyKind keyKind;
  final String purpose;
  final String? description;
  @override
  final int createdAt;
  @override
  final int updatedAt;

  KeychainManifestNostrKey({
    required String entryId,
    required String publicKeyHex,
    required this.keyKind,
    required String purpose,
    String? description,
    required this.createdAt,
    required this.updatedAt,
  }) : entryId = _required(entryId),
       publicKeyHex = publicKeyHex.toLowerCase(),
       purpose = purpose.trim(),
       description = _optional(description) {
    if (!isValid(
      entryId: this.entryId,
      publicKeyHex: this.publicKeyHex,
      purpose: this.purpose,
      description: this.description,
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
    String? description,
    required int createdAt,
    required int updatedAt,
  }) =>
      _tryRequired(entryId) != null &&
      _publicKeyPattern.hasMatch(publicKeyHex.toLowerCase()) &&
      tryNormalizeMetadata(purpose, description) != null &&
      createdAt >= 0 &&
      updatedAt >= 0;

  static ({String purpose, String? description})? tryNormalizeMetadata(
    String purpose,
    String? description,
  ) {
    final normalizedPurpose = purpose.trim();
    final normalizedDescription = _optional(description);
    if (normalizedPurpose.isEmpty ||
        normalizedPurpose.length > maxPurposeLength ||
        _controlPattern.hasMatch(normalizedPurpose) ||
        (normalizedDescription?.length ?? 0) > maxDescriptionLength ||
        (normalizedDescription != null &&
            _controlPattern.hasMatch(normalizedDescription))) {
      return null;
    }
    return (purpose: normalizedPurpose, description: normalizedDescription);
  }

  @override
  String get identity => 'nostr:$entryId';

  late final String npub = NostrBech32.npub(hex.decode(publicKeyHex));
}

final class KeychainManifestImportPlan {
  final KeychainManifest manifest;

  const KeychainManifestImportPlan(this.manifest);

  Fingerprint get parentFingerprint => manifest.parentFingerprint;
  List<KeychainManifestEntry> get entries => manifest.entries;
  Iterable<KeychainManifestWallet> get wallets =>
      entries.expand((entry) => entry.materializations).whereType();
  Iterable<KeychainManifestNostrKey> get nostrKeys =>
      entries.expand((entry) => entry.materializations).whereType();
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

String _canonicalPath(String value) {
  final parts = value.trim().split('/');
  if (parts.length < 2) throw ArgumentError('Invalid BIP85 path');
  final numbers = parts.map(_pathNumber).toList(growable: false);
  return numbers.map((number) => "$number'").join('/');
}

int _pathNumber(String segment) {
  if (!RegExp(r"^(0|[1-9][0-9]*)'$").hasMatch(segment)) {
    throw ArgumentError('Invalid BIP85 path');
  }
  final value = int.parse(segment.substring(0, segment.length - 1));
  if (value > 0x7fffffff) throw ArgumentError('Invalid BIP85 path');
  return value;
}
