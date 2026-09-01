import 'dart:convert';

import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
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
  final List<_EntryModel> entries;

  const _KeychainManifestFileModel({
    required this.version,
    required this.parentFingerprint,
    required this.generatedAt,
    required this.entries,
  });

  factory _KeychainManifestFileModel.fromEntity(KeychainManifest manifest) =>
      _KeychainManifestFileModel(
        version: manifest.version,
        parentFingerprint: manifest.parentFingerprint.hex,
        generatedAt: manifest.generatedAt,
        entries: manifest.entries.map(_EntryModel.fromEntity).toList(),
      );

  static _KeychainManifestFileModel? tryParse(Map<String, Object?> json) {
    if (!_onlyKeys(json, const {
      'version',
      'parentFingerprint',
      'generatedAt',
      'entries',
    })) {
      return null;
    }
    final version = _int(json, 'version');
    final parentFingerprint = _string(json, 'parentFingerprint');
    final generatedAt = _int(json, 'generatedAt');
    final rawEntries = _list(json, 'entries');
    if (version == null ||
        parentFingerprint == null ||
        generatedAt == null ||
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
      entries: entries,
    );
  }

  Map<String, Object?> toJson() => {
    'version': version,
    'parentFingerprint': parentFingerprint,
    'generatedAt': generatedAt,
    'entries': entries.map((entry) => entry.toJson()).toList(),
  };

  Result<KeychainManifest, KeychainManifestFailure> toEntity() {
    final fingerprint = Fingerprint.tryParse(parentFingerprint);
    if (fingerprint == null || !isValidKeychainManifestTimestamp(generatedAt)) {
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
    return Ok(
      KeychainManifest(
        version: version,
        parentFingerprint: fingerprint,
        generatedAt: generatedAt,
        entries: entities,
      ),
    );
  }
}

final class _EntryModel {
  final String derivationKind;
  final String derivationPath;
  final String? description;
  final int createdAt;
  final int updatedAt;
  final List<_MaterializationModel> materializations;

  const _EntryModel({
    required this.derivationKind,
    required this.derivationPath,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    required this.materializations,
  });

  factory _EntryModel.fromEntity(KeychainManifestEntry entry) => _EntryModel(
    derivationKind: entry.derivationKind.name,
    derivationPath: entry.derivationPath,
    description: entry.description,
    createdAt: entry.createdAt,
    updatedAt: entry.updatedAt,
    materializations:
        entry.materializations.map(_MaterializationModel.fromEntity).toList()
          ..sort(_MaterializationModel.compare),
  );

  static _EntryModel? tryParse(Map<String, Object?> json) {
    if (!_onlyKeys(json, const {
      'derivationKind',
      'derivationPath',
      'description',
      'createdAt',
      'updatedAt',
      'materializations',
    })) {
      return null;
    }
    final kind = _string(json, 'derivationKind');
    final path = _string(json, 'derivationPath');
    final createdAt = _int(json, 'createdAt');
    final updatedAt = _int(json, 'updatedAt');
    final rawItems = _list(json, 'materializations');
    if (path == null ||
        kind == null ||
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
      derivationKind: kind,
      derivationPath: path,
      description: _optionalString(json, 'description'),
      createdAt: createdAt,
      updatedAt: updatedAt,
      materializations: items,
    );
  }

  Map<String, Object?> toJson() => {
    'derivationKind': derivationKind,
    'derivationPath': derivationPath,
    if (description != null) 'description': description,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'materializations': materializations.map((item) => item.toJson()).toList(),
  };

  KeychainManifestEntry? toEntity(Fingerprint parentFingerprint) {
    final kind = KeychainManifestDerivationKind.values
        .where((value) => value.name == derivationKind)
        .firstOrNull;
    if (kind == null ||
        !_validPath(kind, derivationPath) ||
        derivationPath.length > maxStringFieldLength ||
        (description?.length ?? 0) >
            KeychainManifestEntry.maxDescriptionLength ||
        (description != null &&
            KeychainManifestNostrKey.hasControlCharacter(description!)) ||
        !isValidKeychainManifestTimestamp(createdAt) ||
        !isValidKeychainManifestTimestamp(updatedAt) ||
        updatedAt < createdAt) {
      return null;
    }
    final seedFingerprint =
        kind == KeychainManifestDerivationKind.bip32 &&
            materializations.length == 1
        ? Fingerprint.tryParse(
            materializations.single.childSeedFingerprint ?? '',
          )
        : null;
    if (kind == KeychainManifestDerivationKind.bip32 &&
        seedFingerprint == null) {
      return null;
    }
    final entryId = KeychainManifestEntry.entryIdFor(
      parentFingerprint: parentFingerprint,
      derivationKind: kind,
      derivationPath: derivationPath,
      seedFingerprint: seedFingerprint,
    );
    final items = <KeychainManifestMaterialization>[];
    for (final item in materializations) {
      final entity = item.toEntity(entryId);
      if (entity == null) return null;
      items.add(entity);
    }
    if (items.any((item) => item.entryId != entryId) ||
        (kind == KeychainManifestDerivationKind.bip32 &&
            (items.length != 1 || items.single is! KeychainManifestWallet))) {
      return null;
    }
    return KeychainManifestEntry(
      parentFingerprint: parentFingerprint,
      derivationKind: kind,
      derivationPath: derivationPath,
      description: description,
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
  final String? provenance;
  final bool? seedPassphraseUsed;
  final String? descriptor;
  final String? label;
  final String? publicKeyHex;
  final String? keyKind;
  final String? purpose;
  final int createdAt;
  final int updatedAt;

  const _MaterializationModel({
    required this.type,
    this.walletId,
    this.childSeedFingerprint,
    this.network,
    this.scriptType,
    this.provenance,
    this.seedPassphraseUsed,
    this.descriptor,
    this.label,
    this.publicKeyHex,
    this.keyKind,
    this.purpose,
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
      provenance: item.provenance.name,
      seedPassphraseUsed: item.seedPassphraseUsed,
      descriptor: item.descriptor,
      label: item.label,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    ),
    KeychainManifestNostrKey() => _MaterializationModel(
      type: 'nostrKey',
      publicKeyHex: item.publicKeyHex,
      keyKind: item.keyKind.name,
      purpose: item.purpose,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    ),
  };

  static _MaterializationModel? tryParse(Map<String, Object?> json) {
    final type = _string(json, 'type');
    final createdAt = _int(json, 'createdAt');
    final updatedAt = _int(json, 'updatedAt');
    if (type == null || createdAt == null || updatedAt == null) return null;
    final allowedKeys = switch (type) {
      'wallet' => const {
        'type',
        'walletId',
        'childSeedFingerprint',
        'network',
        'scriptType',
        'provenance',
        'seedPassphraseUsed',
        'descriptor',
        'label',
        'createdAt',
        'updatedAt',
      },
      'nostrKey' => const {
        'type',
        'publicKeyHex',
        'keyKind',
        'purpose',
        'createdAt',
        'updatedAt',
      },
      _ => const <String>{},
    };
    if (allowedKeys.isEmpty || !_onlyKeys(json, allowedKeys)) return null;
    if (type == 'wallet' &&
        json['seedPassphraseUsed'] != null &&
        json['seedPassphraseUsed'] is! bool) {
      return null;
    }
    return switch (type) {
      'wallet' => _MaterializationModel(
        type: type,
        walletId: _string(json, 'walletId'),
        childSeedFingerprint: _string(json, 'childSeedFingerprint'),
        network: _string(json, 'network'),
        scriptType: _string(json, 'scriptType'),
        provenance: _string(json, 'provenance'),
        seedPassphraseUsed: _optionalBool(json, 'seedPassphraseUsed'),
        descriptor: _optionalString(json, 'descriptor'),
        label: _optionalString(json, 'label'),
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
      'nostrKey' => _MaterializationModel(
        type: type,
        publicKeyHex: _string(json, 'publicKeyHex'),
        keyKind: _string(json, 'keyKind'),
        purpose: _string(json, 'purpose'),
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
      'provenance': provenance,
      'seedPassphraseUsed': seedPassphraseUsed,
      if (descriptor != null) 'descriptor': descriptor,
      if (label != null) 'label': label,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    },
    'nostrKey' => {
      'type': type,
      'publicKeyHex': publicKeyHex,
      'keyKind': keyKind,
      'purpose': purpose,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    },
    _ => throw StateError('Unknown materialization type'),
  };

  KeychainManifestMaterialization? toEntity(String entryId) {
    if (!isValidKeychainManifestTimestamp(createdAt) ||
        !isValidKeychainManifestTimestamp(updatedAt) ||
        updatedAt < createdAt) {
      return null;
    }
    if (type == 'wallet') {
      final fingerprint = Fingerprint.tryParse(childSeedFingerprint ?? '');
      final parsedNetwork = Network.values
          .where((value) => value.name == network)
          .firstOrNull;
      final parsedScript = ScriptType.values
          .where((value) => value.name == scriptType)
          .firstOrNull;
      final parsedProvenance = WalletProvenance.values
          .where((value) => value.name == provenance)
          .firstOrNull;
      if (!_validText(walletId) ||
          fingerprint == null ||
          parsedNetwork == null ||
          parsedScript == null ||
          parsedProvenance == null ||
          !KeychainManifestWallet.isValid(
            walletId: walletId!,
            entryId: entryId,
            provenance: parsedProvenance,
            descriptor: descriptor,
            label: label,
            createdAt: createdAt,
            updatedAt: updatedAt,
          )) {
        return null;
      }
      return KeychainManifestWallet(
        walletId: walletId!,
        entryId: entryId,
        childSeedFingerprint: fingerprint,
        network: parsedNetwork,
        scriptType: parsedScript,
        provenance: parsedProvenance,
        seedPassphraseUsed: seedPassphraseUsed,
        descriptor: descriptor,
        label: label,
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

bool? _optionalBool(Map<String, Object?> json, String key) =>
    json[key] is bool ? json[key]! as bool : null;

List<Object?>? _list(Map<String, Object?> json, String key) =>
    json[key] is List<Object?> ? json[key]! as List<Object?> : null;

bool _validText(String? value) =>
    value != null &&
    value.trim().isNotEmpty &&
    value.length <= maxStringFieldLength;

bool _validPath(KeychainManifestDerivationKind kind, String path) {
  final hasRoot = path.startsWith('m/');
  if (kind == KeychainManifestDerivationKind.bip32 && !hasRoot) return false;
  if (kind == KeychainManifestDerivationKind.bip85 && hasRoot) return false;
  final parts = (hasRoot ? path.substring(2) : path).split('/');
  return parts.length >= 2 && parts.every((part) => _pathNumber(part) != null);
}

int? _pathNumber(String segment) {
  if (!RegExp(r"^(0|[1-9][0-9]*)'$").hasMatch(segment)) return null;
  final value = int.tryParse(segment.substring(0, segment.length - 1));
  return value != null && value <= 0x7fffffff ? value : null;
}

bool _onlyKeys(Map<String, Object?> json, Set<String> allowed) =>
    json.keys.every(allowed.contains);

const maxStringFieldLength = KeychainManifestFileCodec.maxStringFieldLength;
