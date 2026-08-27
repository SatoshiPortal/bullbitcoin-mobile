import 'dart:convert';

import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:primitives/primitives.dart' show Err, Fingerprint, Ok, Result;

final class KeychainManifestFileCodec {
  static const maxPayloadSizeBytes = 1024 * 1024;
  static const maxStringFieldLength = 512;

  const KeychainManifestFileCodec();

  String encode(KeychainManifest manifest) => jsonEncode(
    _KeychainManifestFileModel.fromEntity(manifest.canonical()).toJson(),
  );

  Result<KeychainManifest, KeychainManifestFailure> decode(String payload) {
    if (payload.length > maxPayloadSizeBytes ||
        utf8.encode(payload).length > maxPayloadSizeBytes) {
      return const Err(KeychainManifestMalformedFileFailure());
    }
    final Object? json;
    try {
      json = jsonDecode(payload);
    } on FormatException {
      return const Err(KeychainManifestMalformedFileFailure());
    }
    if (json is! Map<String, Object?>) {
      return const Err(KeychainManifestMalformedFileFailure());
    }
    final version = json['version'];
    if (version is! int) {
      return const Err(KeychainManifestMalformedFileFailure());
    }
    if (version != KeychainManifest.currentVersion) {
      return Err(KeychainManifestUnsupportedVersionFailure(version));
    }
    final model = _KeychainManifestFileModel.tryParse(json);
    if (model == null) {
      return const Err(KeychainManifestMalformedFileFailure());
    }
    return model.toEntity();
  }
}

/// Pure wire representation for version 1 of a Keychain Manifest.
final class _KeychainManifestFileModel {
  final int version;
  final String parentFingerprint;
  final int generatedAt;
  final int inventoryUpdatedAt;
  final int entryCount;
  final int materializationCount;
  final List<_EntryModel> entries;

  const _KeychainManifestFileModel({
    required this.version,
    required this.parentFingerprint,
    required this.generatedAt,
    required this.inventoryUpdatedAt,
    required this.entryCount,
    required this.materializationCount,
    required this.entries,
  });

  factory _KeychainManifestFileModel.fromEntity(KeychainManifest manifest) =>
      _KeychainManifestFileModel(
        version: manifest.version,
        parentFingerprint: manifest.parentFingerprint.hex,
        generatedAt: manifest.generatedAt,
        inventoryUpdatedAt: manifest.inventoryUpdatedAt,
        entryCount: manifest.entryCount,
        materializationCount: manifest.materializationCount,
        entries: manifest.entries.map(_EntryModel.fromEntity).toList(),
      );

  static _KeychainManifestFileModel? tryParse(Map<String, Object?> json) {
    final version = _int(json, 'version');
    final parentFingerprint = _string(json, 'parentFingerprint');
    final generatedAt = _int(json, 'generatedAt');
    final inventoryUpdatedAt = _int(json, 'inventoryUpdatedAt');
    final entryCount = _int(json, 'entryCount');
    final materializationCount = _int(json, 'materializationCount');
    final rawEntries = _list(json, 'entries');
    if (version == null ||
        parentFingerprint == null ||
        generatedAt == null ||
        inventoryUpdatedAt == null ||
        entryCount == null ||
        materializationCount == null ||
        rawEntries == null) {
      return null;
    }
    final entries = <_EntryModel>[];
    for (final raw in rawEntries) {
      if (raw is! Map<String, Object?>) return null;
      final entry = _EntryModel.tryParse(raw);
      if (entry == null) return null;
      entries.add(entry);
    }
    return _KeychainManifestFileModel(
      version: version,
      parentFingerprint: parentFingerprint,
      generatedAt: generatedAt,
      inventoryUpdatedAt: inventoryUpdatedAt,
      entryCount: entryCount,
      materializationCount: materializationCount,
      entries: entries,
    );
  }

  Map<String, Object?> toJson() => {
    'version': version,
    'parentFingerprint': parentFingerprint,
    'generatedAt': generatedAt,
    'inventoryUpdatedAt': inventoryUpdatedAt,
    'entryCount': entryCount,
    'materializationCount': materializationCount,
    'entries': entries.map((entry) => entry.toJson()).toList(),
  };

  Result<KeychainManifest, KeychainManifestFailure> toEntity() {
    final fingerprint = Fingerprint.tryParse(parentFingerprint);
    if (fingerprint == null ||
        generatedAt < 0 ||
        inventoryUpdatedAt < 0 ||
        entryCount != entries.length) {
      return const Err(KeychainManifestMalformedFileFailure());
    }
    final entities = <KeychainManifestEntry>[];
    final entryIds = <String>{};
    final materializationIds = <String>{};
    for (final entry in entries) {
      final entity = entry.toEntity(fingerprint);
      if (entity == null || !entryIds.add(entity.entryId)) {
        return const Err(KeychainManifestMalformedFileFailure());
      }
      for (final item in entity.materializations) {
        if (!materializationIds.add(item.identity)) {
          return const Err(KeychainManifestMalformedFileFailure());
        }
      }
      entities.add(entity);
    }
    final materializations = entities.fold(
      0,
      (count, entry) => count + entry.materializations.length,
    );
    if (materializationCount != materializations) {
      return const Err(KeychainManifestMalformedFileFailure());
    }
    final manifest = KeychainManifest(
      version: version,
      parentFingerprint: fingerprint,
      generatedAt: generatedAt,
      entries: entities,
    );
    if (inventoryUpdatedAt != manifest.inventoryUpdatedAt) {
      return const Err(KeychainManifestMalformedFileFailure());
    }
    return Ok(manifest);
  }
}

final class _EntryModel {
  final String entryId;
  final String bip85DerivationPath;
  final String reservationId;
  final String entryType;
  final String ownerFeature;
  final int bip85Application;
  final int bip85Index;
  final int createdAt;
  final int updatedAt;
  final List<_MaterializationModel> materializations;

  const _EntryModel({
    required this.entryId,
    required this.bip85DerivationPath,
    required this.reservationId,
    required this.entryType,
    required this.ownerFeature,
    required this.bip85Application,
    required this.bip85Index,
    required this.createdAt,
    required this.updatedAt,
    required this.materializations,
  });

  factory _EntryModel.fromEntity(KeychainManifestEntry entry) => _EntryModel(
    entryId: entry.entryId,
    bip85DerivationPath: entry.bip85DerivationPath,
    reservationId: entry.reservationId,
    entryType: entry.entryType,
    ownerFeature: entry.ownerFeature,
    bip85Application: entry.bip85Application,
    bip85Index: entry.bip85Index,
    createdAt: entry.createdAt,
    updatedAt: entry.updatedAt,
    materializations:
        entry.materializations.map(_MaterializationModel.fromEntity).toList()
          ..sort(_MaterializationModel.compare),
  );

  static _EntryModel? tryParse(Map<String, Object?> json) {
    final entryId = _string(json, 'entryId');
    final path = _string(json, 'bip85DerivationPath');
    final reservationId = _string(json, 'reservationId');
    final entryType = _string(json, 'entryType');
    final ownerFeature = _string(json, 'ownerFeature');
    final application = _int(json, 'bip85Application');
    final index = _int(json, 'bip85Index');
    final createdAt = _int(json, 'createdAt');
    final updatedAt = _int(json, 'updatedAt');
    final rawItems = _list(json, 'materializations');
    if (entryId == null ||
        path == null ||
        reservationId == null ||
        entryType == null ||
        ownerFeature == null ||
        application == null ||
        index == null ||
        createdAt == null ||
        updatedAt == null ||
        rawItems == null ||
        rawItems.isEmpty ||
        rawItems.length > 8) {
      return null;
    }
    final items = <_MaterializationModel>[];
    for (final raw in rawItems) {
      if (raw is! Map<String, Object?>) return null;
      final item = _MaterializationModel.tryParse(raw);
      if (item == null) return null;
      items.add(item);
    }
    return _EntryModel(
      entryId: entryId,
      bip85DerivationPath: path,
      reservationId: reservationId,
      entryType: entryType,
      ownerFeature: ownerFeature,
      bip85Application: application,
      bip85Index: index,
      createdAt: createdAt,
      updatedAt: updatedAt,
      materializations: items,
    );
  }

  Map<String, Object?> toJson() => {
    'entryId': entryId,
    'bip85DerivationPath': bip85DerivationPath,
    'reservationId': reservationId,
    'entryType': entryType,
    'ownerFeature': ownerFeature,
    'bip85Application': bip85Application,
    'bip85Index': bip85Index,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'materializations': materializations.map((item) => item.toJson()).toList(),
  };

  KeychainManifestEntry? toEntity(Fingerprint parentFingerprint) {
    if (!_validPath(bip85DerivationPath) ||
        bip85DerivationPath.length > maxStringFieldLength ||
        entryId != '${parentFingerprint.hex}:$bip85DerivationPath' ||
        !_validText(reservationId) ||
        !_validText(entryType) ||
        !_validText(ownerFeature) ||
        createdAt < 0 ||
        updatedAt < 0) {
      return null;
    }
    final parts = bip85DerivationPath.split('/');
    if (bip85Application != _pathNumber(parts.first) ||
        bip85Index != _pathNumber(parts.last)) {
      return null;
    }
    final items = <KeychainManifestMaterialization>[];
    for (final item in materializations) {
      final entity = item.toEntity(entryId);
      if (entity == null) return null;
      items.add(entity);
    }
    return KeychainManifestEntry(
      parentFingerprint: parentFingerprint,
      bip85DerivationPath: bip85DerivationPath,
      reservationId: reservationId,
      entryType: entryType,
      ownerFeature: ownerFeature,
      bip85Application: bip85Application,
      bip85Index: bip85Index,
      createdAt: createdAt,
      updatedAt: updatedAt,
      materializations: items,
    );
  }
}

final class _MaterializationModel {
  final String type;
  final String? walletId;
  final String? childSeedFingerprint;
  final String? network;
  final String? scriptType;
  final String? publicKeyHex;
  final String? keyKind;
  final String? purpose;
  final String? description;
  final int createdAt;
  final int updatedAt;

  const _MaterializationModel({
    required this.type,
    this.walletId,
    this.childSeedFingerprint,
    this.network,
    this.scriptType,
    this.publicKeyHex,
    this.keyKind,
    this.purpose,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory _MaterializationModel.fromEntity(
    KeychainManifestMaterialization item,
  ) => switch (item) {
    KeychainManifestWallet() => _MaterializationModel(
      type: 'wallet',
      walletId: item.walletId,
      childSeedFingerprint: item.childSeedFingerprint.hex,
      network: item.network.name,
      scriptType: item.scriptType.name,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    ),
    KeychainManifestNostrKey() => _MaterializationModel(
      type: 'nostrKey',
      publicKeyHex: item.publicKeyHex,
      keyKind: item.keyKind.name,
      purpose: item.purpose,
      description: item.description,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    ),
  };

  static _MaterializationModel? tryParse(Map<String, Object?> json) {
    final type = _string(json, 'type');
    final createdAt = _int(json, 'createdAt');
    final updatedAt = _int(json, 'updatedAt');
    if (type == null || createdAt == null || updatedAt == null) return null;
    return switch (type) {
      'wallet' => _MaterializationModel(
        type: type,
        walletId: _string(json, 'walletId'),
        childSeedFingerprint: _string(json, 'childSeedFingerprint'),
        network: _string(json, 'network'),
        scriptType: _string(json, 'scriptType'),
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
      'nostrKey' => _MaterializationModel(
        type: type,
        publicKeyHex: _string(json, 'publicKeyHex'),
        keyKind: _string(json, 'keyKind'),
        purpose: _string(json, 'purpose'),
        description: _optionalString(json, 'description'),
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
      _ => null,
    };
  }

  Map<String, Object?> toJson() => switch (type) {
    'wallet' => {
      'type': type,
      'walletId': walletId,
      'childSeedFingerprint': childSeedFingerprint,
      'network': network,
      'scriptType': scriptType,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    },
    'nostrKey' => {
      'type': type,
      'publicKeyHex': publicKeyHex,
      'keyKind': keyKind,
      'purpose': purpose,
      if (description != null) 'description': description,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    },
    _ => throw StateError('Unknown materialization type'),
  };

  KeychainManifestMaterialization? toEntity(String entryId) {
    if (createdAt < 0 || updatedAt < 0) return null;
    if (type == 'wallet') {
      final fingerprint = Fingerprint.tryParse(childSeedFingerprint ?? '');
      final parsedNetwork = Network.values
          .where((value) => value.name == network)
          .firstOrNull;
      final parsedScript = ScriptType.values
          .where((value) => value.name == scriptType)
          .firstOrNull;
      if (!_validText(walletId) ||
          fingerprint == null ||
          parsedNetwork == null ||
          parsedScript == null) {
        return null;
      }
      return KeychainManifestWallet(
        walletId: walletId!,
        entryId: entryId,
        childSeedFingerprint: fingerprint,
        network: parsedNetwork,
        scriptType: parsedScript,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
    }
    final kind = KeychainManifestNostrKeyKind.values
        .where((value) => value.name == keyKind)
        .firstOrNull;
    if (kind == null ||
        publicKeyHex == null ||
        purpose == null ||
        !KeychainManifestNostrKey.isValid(
          entryId: entryId,
          publicKeyHex: publicKeyHex!,
          purpose: purpose!,
          description: description,
          createdAt: createdAt,
          updatedAt: updatedAt,
        )) {
      return null;
    }
    return KeychainManifestNostrKey(
      entryId: entryId,
      publicKeyHex: publicKeyHex!,
      keyKind: kind,
      purpose: purpose!,
      description: description,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static int compare(_MaterializationModel left, _MaterializationModel right) {
    final byType = left.type.compareTo(right.type);
    if (byType != 0) return byType;
    final byNetwork = (left.network ?? '').compareTo(right.network ?? '');
    if (byNetwork != 0) return byNetwork;
    return (left.walletId ?? left.publicKeyHex ?? '').compareTo(
      right.walletId ?? right.publicKeyHex ?? '',
    );
  }
}

String? _string(Map<String, Object?> json, String key) {
  final value = json[key];
  return value is String && value.length <= maxStringFieldLength ? value : null;
}

String? _optionalString(Map<String, Object?> json, String key) =>
    !json.containsKey(key) || json[key] == null ? null : _string(json, key);

int? _int(Map<String, Object?> json, String key) =>
    json[key] is int ? json[key]! as int : null;

List<Object?>? _list(Map<String, Object?> json, String key) =>
    json[key] is List<Object?> ? json[key]! as List<Object?> : null;

bool _validText(String? value) =>
    value != null &&
    value.trim().isNotEmpty &&
    value.length <= maxStringFieldLength;

bool _validPath(String path) {
  final parts = path.split('/');
  return parts.length >= 2 && parts.every((part) => _pathNumber(part) != null);
}

int? _pathNumber(String segment) {
  if (!RegExp(r"^(0|[1-9][0-9]*)'$").hasMatch(segment)) return null;
  final value = int.tryParse(segment.substring(0, segment.length - 1));
  return value != null && value <= 0x7fffffff ? value : null;
}

const maxStringFieldLength = KeychainManifestFileCodec.maxStringFieldLength;
