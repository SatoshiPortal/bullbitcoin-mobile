import 'dart:convert';

import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_file.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_import.dart';

class ParseKeychainManifestFileUsecase {
  final Bip85RegistryFacade registry;

  const ParseKeychainManifestFileUsecase({
    this.registry = const Bip85RegistryFacade(),
  });

  KeychainManifestImportPlan execute(String payload) {
    try {
      final manifestFile = const _KeychainManifestFileDecoder().decode(payload);
      final entries = manifestFile.entries
          .map(_entryIntent)
          .toList(growable: false);
      return KeychainManifestImportPlan(
        parentFingerprint: manifestFile.parentFingerprint,
        entries: entries,
      );
    } on KeychainManifestException catch (e) {
      throw KeychainManifestFileParseException(cause: e);
    } catch (e) {
      throw KeychainManifestFileParseException(cause: e);
    }
  }

  KeychainManifestImportEntryIntent _entryIntent(
    KeychainManifestFileEntry entry,
  ) {
    final reservation = registry.reservationById(entry.reservationId);
    if (reservation == null) {
      throw KeychainManifestInvalidEntryException(
        'manifest file reservation id is unknown',
      );
    }
    if (!reservation.scope.matchesExactPath(entry.bip85DerivationPath)) {
      throw KeychainManifestInvalidEntryException(
        'manifest file reservation path mismatch',
      );
    }
    if (reservation.owner.name != entry.ownerFeature ||
        reservation.purpose.name != entry.entryType ||
        reservation.application.number != entry.bip85Application ||
        reservation.scope.segmentValue('index') != entry.bip85Index) {
      throw KeychainManifestInvalidEntryException(
        'manifest file reservation metadata mismatch',
      );
    }
    return KeychainManifestImportEntryIntent.fromFileEntry(
      entry,
      walletMaterializations: _walletMaterializations(entry),
    );
  }

  List<KeychainManifestWalletMaterializationIntent> _walletMaterializations(
    KeychainManifestFileEntry entry,
  ) {
    // Duplicate wallet ids are rejected by the KeychainManifestFile entity
    // when the payload is decoded, so every materialization reaching this
    // point is unique.
    return entry.materializations
        .map(
          (materialization) =>
              KeychainManifestWalletMaterializationIntent.fromFileMaterialization(
                entry: entry,
                materialization: materialization,
              ),
        )
        .toList(growable: false);
  }
}

class _KeychainManifestFileDecoder {
  const _KeychainManifestFileDecoder();

  KeychainManifestFile decode(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, Object?>) {
        throw KeychainManifestInvalidEntryException(
          'manifest file payload must be a JSON object',
        );
      }
      return _manifestFromJson(decoded);
    } on KeychainManifestException {
      rethrow;
    } on FormatException catch (e) {
      throw KeychainManifestInvalidEntryException(
        'manifest file payload is not valid JSON: ${e.message}',
      );
    } catch (e) {
      throw KeychainManifestInvalidEntryException(
        'manifest file payload is invalid: $e',
      );
    }
  }

  KeychainManifestFile _manifestFromJson(Map<String, Object?> json) {
    final parentFingerprint = _string(json, 'parentFingerprint');
    // Required v1 integrity fields: the shape check enforces their presence
    // and type; the entity derives its own values from the actual entries.
    _int(json, 'inventoryUpdatedAt');
    _int(json, 'entryCount');
    _int(json, 'materializationCount');
    return KeychainManifestFile(
      version: _int(json, 'version'),
      parentFingerprint: parentFingerprint,
      generatedAt: _int(json, 'generatedAt'),
      entries: _list(json, 'entries')
          .map(
            (entry) => _entryFromJson(
              _map(entry, 'entries item'),
              parentFingerprint: parentFingerprint,
            ),
          )
          .toList(growable: false),
    );
  }

  KeychainManifestFileEntry _entryFromJson(
    Map<String, Object?> json, {
    required String parentFingerprint,
  }) {
    final entryId = _string(json, 'entryId');
    return KeychainManifestFileEntry(
      entryId: entryId,
      parentFingerprint: parentFingerprint,
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
            (materialization) => _materializationFromJson(
              _map(materialization, 'materializations item'),
              entryId: entryId,
            ),
          )
          .toList(growable: false),
    );
  }

  KeychainManifestFileWalletMaterialization _materializationFromJson(
    Map<String, Object?> json, {
    required String entryId,
  }) {
    final type = _string(json, 'type');
    if (type != KeychainManifestFileWalletMaterialization.type) {
      throw KeychainManifestInvalidEntryException(
        'unsupported manifest materialization type: $type',
      );
    }
    return KeychainManifestFileWalletMaterialization(
      walletId: _string(json, 'walletId'),
      entryId: entryId,
      childSeedFingerprint: _string(json, 'childSeedFingerprint'),
      network: _string(json, 'network'),
      scriptType: _string(json, 'scriptType'),
      createdAt: _int(json, 'createdAt'),
      updatedAt: _int(json, 'updatedAt'),
    );
  }

  String _string(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is String) return value;
    throw KeychainManifestInvalidEntryException(
      'manifest file field "$key" must be a string',
    );
  }

  int _int(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is int) return value;
    throw KeychainManifestInvalidEntryException(
      'manifest file field "$key" must be an integer',
    );
  }

  List<Object?> _list(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is List<Object?>) return value;
    throw KeychainManifestInvalidEntryException(
      'manifest file field "$key" must be a list',
    );
  }

  Map<String, Object?> _map(Object? value, String description) {
    if (value is Map<String, Object?>) return value;
    throw KeychainManifestInvalidEntryException(
      'manifest file $description must be an object',
    );
  }
}
