import 'dart:convert';

import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_file.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart';

class KeychainManifestFileCodec {
  const KeychainManifestFileCodec();

  String encode(KeychainManifestFile manifestFile) {
    return jsonEncode(
      _KeychainManifestFileModel.fromEntity(manifestFile).toJson(),
    );
  }

  KeychainManifestFile decode(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, Object?>) {
        throw KeychainManifestFileParseException(
          reason: KeychainManifestFileParseFailureReason.malformedFile,
        );
      }
      final model = _KeychainManifestFileModel.fromJson(decoded);
      final manifestFile = model.toEntity();
      // The entity owns the derivation of the data-recency timestamp; a
      // declared wire value that disagrees with the actual entries is an
      // inconsistent file.
      if (model.inventoryUpdatedAt != manifestFile.inventoryUpdatedAt) {
        throw KeychainManifestFileParseException(
          reason: KeychainManifestFileParseFailureReason.invalidMetadata,
        );
      }
      return manifestFile;
    } on KeychainManifestFileParseException {
      rethrow;
    } on FormatException catch (e) {
      throw KeychainManifestFileParseException(
        reason: KeychainManifestFileParseFailureReason.malformedFile,
        cause: e,
      );
    } on KeychainManifestInvalidEntryException catch (e) {
      throw KeychainManifestFileParseException(
        reason: _reasonForInvalidEntry(e),
        cause: e,
      );
    } catch (e) {
      throw KeychainManifestFileParseException(
        reason: KeychainManifestFileParseFailureReason.invalidMetadata,
        cause: e,
      );
    }
  }

  KeychainManifestFileParseFailureReason _reasonForInvalidEntry(
    KeychainManifestInvalidEntryException exception,
  ) {
    return switch (exception.message) {
      'unsupported keychain manifest file version' =>
        KeychainManifestFileParseFailureReason.unsupportedVersion,
      _ => KeychainManifestFileParseFailureReason.invalidMetadata,
    };
  }
}

class _KeychainManifestFileModel {
  final int version;
  final String parentFingerprint;
  final int generatedAt;
  final int inventoryUpdatedAt;
  final int entryCount;
  final int materializationCount;
  final List<_KeychainManifestFileEntryModel> entries;

  const _KeychainManifestFileModel({
    required this.version,
    required this.parentFingerprint,
    required this.generatedAt,
    required this.inventoryUpdatedAt,
    required this.entryCount,
    required this.materializationCount,
    required this.entries,
  });

  factory _KeychainManifestFileModel.fromEntity(
    KeychainManifestFile manifestFile,
  ) {
    return _KeychainManifestFileModel(
      version: manifestFile.version,
      parentFingerprint: manifestFile.parentFingerprint,
      generatedAt: manifestFile.generatedAt,
      inventoryUpdatedAt: manifestFile.inventoryUpdatedAt,
      entryCount: manifestFile.entryCount,
      materializationCount: manifestFile.materializationCount,
      entries: manifestFile.entries
          .map(_KeychainManifestFileEntryModel.fromEntity)
          .toList(growable: false),
    );
  }

  factory _KeychainManifestFileModel.fromJson(Map<String, Object?> json) {
    return _KeychainManifestFileModel(
      version: _int(json, 'version'),
      parentFingerprint: _string(json, 'parentFingerprint'),
      generatedAt: _int(json, 'generatedAt'),
      inventoryUpdatedAt: _int(json, 'inventoryUpdatedAt'),
      entryCount: _int(json, 'entryCount'),
      materializationCount: _int(json, 'materializationCount'),
      entries: _list(json, 'entries')
          .map((entry) => _KeychainManifestFileEntryModel.fromJson(_map(entry)))
          .toList(growable: false),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'version': version,
      'parentFingerprint': parentFingerprint,
      'generatedAt': generatedAt,
      'inventoryUpdatedAt': inventoryUpdatedAt,
      'entryCount': entryCount,
      'materializationCount': materializationCount,
      'entries': entries.map((entry) => entry.toJson()).toList(growable: false),
    };
  }

  KeychainManifestFile toEntity() {
    return KeychainManifestFile(
      version: version,
      parentFingerprint: parentFingerprint,
      generatedAt: generatedAt,
      entries: entries
          .map((entry) => entry.toEntity(parentFingerprint: parentFingerprint))
          .toList(growable: false),
    );
  }
}

class _KeychainManifestFileEntryModel {
  final String entryId;
  final String bip85DerivationPath;
  final String reservationId;
  final String entryType;
  final String ownerFeature;
  final int bip85Application;
  final int bip85Index;
  final int createdAt;
  final int updatedAt;
  final List<_KeychainManifestFileWalletMaterializationModel> materializations;

  const _KeychainManifestFileEntryModel({
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

  factory _KeychainManifestFileEntryModel.fromEntity(
    KeychainManifestFileEntry entry,
  ) {
    return _KeychainManifestFileEntryModel(
      entryId: entry.entryId,
      bip85DerivationPath: entry.bip85DerivationPath,
      reservationId: entry.reservationId,
      entryType: entry.entryType,
      ownerFeature: entry.ownerFeature,
      bip85Application: entry.bip85Application,
      bip85Index: entry.bip85Index,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
      materializations: entry.materializations
          .map(_KeychainManifestFileWalletMaterializationModel.fromEntity)
          .toList(growable: false),
    );
  }

  factory _KeychainManifestFileEntryModel.fromJson(Map<String, Object?> json) {
    return _KeychainManifestFileEntryModel(
      entryId: _string(json, 'entryId'),
      bip85DerivationPath: _string(json, 'bip85DerivationPath'),
      reservationId: _string(json, 'reservationId'),
      entryType: _string(json, 'entryType'),
      ownerFeature: _string(json, 'ownerFeature'),
      bip85Application: _int(json, 'bip85Application'),
      bip85Index: _int(json, 'bip85Index'),
      createdAt: _int(json, 'createdAt'),
      updatedAt: _int(json, 'updatedAt'),
      materializations: _list(json, 'materializations')
          .map(
            (materialization) =>
                _KeychainManifestFileWalletMaterializationModel.fromJson(
                  _map(materialization),
                ),
          )
          .toList(growable: false),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'entryId': entryId,
      'bip85DerivationPath': bip85DerivationPath,
      'reservationId': reservationId,
      'entryType': entryType,
      'ownerFeature': ownerFeature,
      'bip85Application': bip85Application,
      'bip85Index': bip85Index,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'materializations': materializations
          .map((materialization) => materialization.toJson())
          .toList(growable: false),
    };
  }

  KeychainManifestFileEntry toEntity({required String parentFingerprint}) {
    return KeychainManifestFileEntry(
      entryId: entryId,
      parentFingerprint: parentFingerprint,
      bip85DerivationPath: bip85DerivationPath,
      reservationId: reservationId,
      entryType: entryType,
      ownerFeature: ownerFeature,
      bip85Application: bip85Application,
      bip85Index: bip85Index,
      createdAt: createdAt,
      updatedAt: updatedAt,
      materializations: materializations
          .map((materialization) => materialization.toEntity(entryId: entryId))
          .toList(growable: false),
    );
  }
}

class _KeychainManifestFileWalletMaterializationModel {
  final String type;
  final String walletId;
  final String childSeedFingerprint;
  final String network;
  final String scriptType;
  final int createdAt;
  final int updatedAt;

  const _KeychainManifestFileWalletMaterializationModel({
    required this.type,
    required this.walletId,
    required this.childSeedFingerprint,
    required this.network,
    required this.scriptType,
    required this.createdAt,
    required this.updatedAt,
  });

  factory _KeychainManifestFileWalletMaterializationModel.fromEntity(
    KeychainManifestFileWalletMaterialization materialization,
  ) {
    return _KeychainManifestFileWalletMaterializationModel(
      type: KeychainManifestFileWalletMaterialization.type,
      walletId: materialization.walletId,
      childSeedFingerprint: materialization.childSeedFingerprint,
      network: materialization.network,
      scriptType: materialization.scriptType,
      createdAt: materialization.createdAt,
      updatedAt: materialization.updatedAt,
    );
  }

  factory _KeychainManifestFileWalletMaterializationModel.fromJson(
    Map<String, Object?> json,
  ) {
    final type = _string(json, 'type');
    if (type != KeychainManifestFileWalletMaterialization.type) {
      throw KeychainManifestFileParseException(
        reason: KeychainManifestFileParseFailureReason.invalidMetadata,
      );
    }
    return _KeychainManifestFileWalletMaterializationModel(
      type: type,
      walletId: _string(json, 'walletId'),
      childSeedFingerprint: _string(json, 'childSeedFingerprint'),
      network: _string(json, 'network'),
      scriptType: _string(json, 'scriptType'),
      createdAt: _int(json, 'createdAt'),
      updatedAt: _int(json, 'updatedAt'),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'type': type,
      'walletId': walletId,
      'childSeedFingerprint': childSeedFingerprint,
      'network': network,
      'scriptType': scriptType,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  KeychainManifestFileWalletMaterialization toEntity({
    required String entryId,
  }) {
    return KeychainManifestFileWalletMaterialization(
      walletId: walletId,
      entryId: entryId,
      childSeedFingerprint: childSeedFingerprint,
      network: network,
      scriptType: scriptType,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw KeychainManifestFileParseException(
    reason: KeychainManifestFileParseFailureReason.malformedFile,
  );
}

int _int(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw KeychainManifestFileParseException(
    reason: KeychainManifestFileParseFailureReason.malformedFile,
  );
}

List<Object?> _list(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is List<Object?>) return value;
  throw KeychainManifestFileParseException(
    reason: KeychainManifestFileParseFailureReason.malformedFile,
  );
}

Map<String, Object?> _map(Object? value) {
  if (value is Map<String, Object?>) return value;
  throw KeychainManifestFileParseException(
    reason: KeychainManifestFileParseFailureReason.malformedFile,
  );
}
