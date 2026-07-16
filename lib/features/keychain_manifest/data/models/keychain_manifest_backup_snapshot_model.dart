import 'dart:convert';

import 'package:bb_mobile/features/keychain_manifest/data/models/keychain_manifest_file_model.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_backup_snapshot.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart';

final class KeychainManifestBackupSnapshotCodec {
  static const _manifestFileKey = 'manifestFile';

  final KeychainManifestFileCodec manifestFileCodec;

  const KeychainManifestBackupSnapshotCodec({
    this.manifestFileCodec = const KeychainManifestFileCodec(),
  });

  String encode(KeychainManifestBackupSnapshot snapshot) {
    final manifestJson = jsonDecode(
      manifestFileCodec.encode(snapshot.manifestFile),
    );
    return jsonEncode({
      'version': snapshot.version,
      'contentType': snapshot.contentType,
      _manifestFileKey: manifestJson,
    });
  }

  KeychainManifestBackupSnapshot decode(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, Object?>) {
        throw KeychainManifestBackupSnapshotException(
          'keychain manifest backup snapshot must be a JSON object',
        );
      }
      final version = _int(decoded, 'version');
      if (version > KeychainManifestBackupSnapshot.currentVersion) {
        throw KeychainManifestUnsupportedVersionException(version);
      }
      final contentType = _string(decoded, 'contentType');
      final manifestFileJson = _map(
        decoded[_manifestFileKey],
        _manifestFileKey,
      );
      return KeychainManifestBackupSnapshot(
        version: version,
        contentType: contentType,
        manifestFile: manifestFileCodec.decode(jsonEncode(manifestFileJson)),
      );
    } on KeychainManifestException {
      rethrow;
    } on FormatException catch (error) {
      throw KeychainManifestBackupSnapshotException(
        'keychain manifest backup snapshot is malformed',
        cause: error,
      );
    } catch (error) {
      throw KeychainManifestBackupSnapshotException(
        'keychain manifest backup snapshot is invalid',
        cause: error,
      );
    }
  }
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw KeychainManifestBackupSnapshotException(
    'keychain manifest backup snapshot field $key must be a string',
  );
}

int _int(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw KeychainManifestBackupSnapshotException(
    'keychain manifest backup snapshot field $key must be an integer',
  );
}

Map<String, Object?> _map(Object? value, String description) {
  if (value is Map<String, Object?>) return value;
  throw KeychainManifestBackupSnapshotException(
    'keychain manifest backup snapshot field $description must be an object',
  );
}
