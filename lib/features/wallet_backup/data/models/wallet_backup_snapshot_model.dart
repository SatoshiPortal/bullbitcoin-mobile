import 'dart:convert';

import 'package:bb_mobile/core/wallet/domain/entities/wallet_definition.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/wallet_backup/data/models/wallet_definitions_model.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_file_comparison.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/data/wallet_metadata_snapshot_codec.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_snapshot.dart';
import 'package:primitives/primitives.dart' show Err, Fingerprint, Ok, Result;

enum WalletBackupSnapshotCodecFailureReason {
  malformed,
  unsupportedVersion,
  manifestRejected,
  parentFingerprintMismatch,
  tooLarge,
}

final class WalletBackupSnapshotCodecException implements Exception {
  final WalletBackupSnapshotCodecFailureReason reason;
  final int? version;
  final String? detail;

  const WalletBackupSnapshotCodecException({
    required this.reason,
    this.version,
    this.detail,
  });
}

typedef EncodeKeychainManifestSection = String Function(KeychainManifest);
typedef DecodeKeychainManifestSection =
    Result<KeychainManifest, KeychainManifestFailure> Function(
      String payload, {
      required Fingerprint expectedParentFingerprint,
      bool allowEmpty,
    });

/// The one canonical Bull backup document: outer envelope version 1 over three
/// independently versioned sections.
///
/// Each section's wire form is owned by the domain that produces it; this codec
/// only frames them, checks the versions and the parent fingerprint, and fixes
/// the key order.
final class WalletBackupSnapshotCodec {
  static const _requiredKeys = {
    'format',
    'version',
    'parentFingerprint',
    'createdAt',
    'manifest',
  };
  static const _allowedKeys = {..._requiredKeys, 'definitions', 'metadata'};

  /// RecoverBull adds a 16-byte nonce, up to 16 bytes of AES-CBC padding, and
  /// a 32-byte HMAC. Leaving 64 bytes keeps ciphertext within 1 MiB.
  static const maxPlaintextSizeBytes = 1024 * 1024 - 64;

  final EncodeKeychainManifestSection _encodeManifest;
  final DecodeKeychainManifestSection _decodeManifest;
  final WalletDefinitionsCodec _definitions;
  final WalletMetadataSnapshotCodec _metadata;

  const WalletBackupSnapshotCodec({
    required this._encodeManifest,
    required this._decodeManifest,
    this._definitions = const WalletDefinitionsCodec(),
    this._metadata = const WalletMetadataSnapshotCodec(),
  });

  String encode(WalletBackupSnapshot snapshot) {
    final metadata = snapshot.metadata;
    final encoded = jsonEncode({
      'format': WalletBackupSnapshot.format,
      'version': WalletBackupSnapshot.currentVersion,
      'parentFingerprint': snapshot.parentFingerprint.hex,
      'createdAt': snapshot.createdAt,
      'manifest': _section(_encodeManifest(snapshot.recoveryManifest)),
      'definitions': ?snapshot.externalWalletDefinitions.isEmpty
          ? null
          : _section(_definitions.encode(snapshot.externalWalletDefinitions)),
      'metadata': ?metadata == null
          ? null
          : _section(_metadata.encode(metadata)),
    });
    _checkSize(encoded);
    return encoded;
  }

  WalletBackupSnapshot decode(
    String payload, {
    required Fingerprint expectedParentFingerprint,
  }) {
    _checkSize(payload);
    try {
      final root = _object(jsonDecode(payload));
      _expectKeys(root);
      if (_string(root, 'format') != WalletBackupSnapshot.format) {
        throw _malformed('format');
      }
      _expectVersion(
        _int(root, 'version'),
        WalletBackupSnapshot.currentVersion,
      );
      final parentFingerprint = _fingerprint(
        _string(root, 'parentFingerprint'),
      );
      if (parentFingerprint != expectedParentFingerprint) {
        throw const WalletBackupSnapshotCodecException(
          reason:
              WalletBackupSnapshotCodecFailureReason.parentFingerprintMismatch,
        );
      }
      return WalletBackupSnapshot(
        parentFingerprint: parentFingerprint,
        createdAt: _int(root, 'createdAt'),
        recoveryManifest: _decodeManifestSection(
          root['manifest'],
          parentFingerprint,
        ),
        externalWalletDefinitions: _decodeDefinitionsSection(
          root['definitions'],
        ),
        metadata: _decodeMetadataSection(root['metadata']),
      );
    } on WalletBackupSnapshotCodecException {
      rethrow;
    } on FormatException {
      throw _malformed('json');
    } on ArgumentError {
      throw _malformed('bounds');
    }
  }

  /// Which sections of two snapshots hold different content.
  ///
  /// Sections are compared by their canonical section encoding, so the answer
  /// covers every field the wire form carries and nothing it does not. The
  /// manifest's `generatedAt` stamp is not content: it moves on every publish.
  Set<WalletBackupDifference> differences(
    WalletBackupSnapshot left,
    WalletBackupSnapshot right,
  ) => {
    if (_encodeManifest(_undated(left.recoveryManifest)) !=
        _encodeManifest(_undated(right.recoveryManifest)))
      WalletBackupDifference.walletManifest,
    if (_encodeDefinitions(left) != _encodeDefinitions(right))
      WalletBackupDifference.externalWallets,
    if (_encodeMetadata(left) != _encodeMetadata(right))
      WalletBackupDifference.protectedData,
  };

  String? _encodeDefinitions(WalletBackupSnapshot snapshot) =>
      snapshot.externalWalletDefinitions.isEmpty
      ? null
      : _definitions.encode(snapshot.externalWalletDefinitions);

  String? _encodeMetadata(WalletBackupSnapshot snapshot) {
    final metadata = snapshot.metadata;
    return metadata == null ? null : _metadata.encode(metadata);
  }

  KeychainManifest _decodeManifestSection(
    Object? value,
    Fingerprint parentFingerprint,
  ) {
    final section = _object(value);
    _expectVersion(_int(section, 'version'), KeychainManifest.currentVersion);
    final decoded = _decodeManifest(
      jsonEncode(section),
      expectedParentFingerprint: parentFingerprint,
      allowEmpty: true,
    );
    return switch (decoded) {
      Ok(:final value) => value,
      Err(failure: KeychainManifestUnsupportedVersionFailure(:final version)) =>
        throw WalletBackupSnapshotCodecException(
          reason: WalletBackupSnapshotCodecFailureReason.unsupportedVersion,
          version: version,
        ),
      Err(failure: KeychainManifestParentMismatchFailure()) =>
        throw const WalletBackupSnapshotCodecException(
          reason:
              WalletBackupSnapshotCodecFailureReason.parentFingerprintMismatch,
        ),
      Err(:final failure) => throw WalletBackupSnapshotCodecException(
        reason: WalletBackupSnapshotCodecFailureReason.manifestRejected,
        detail: failure.runtimeType.toString(),
      ),
    };
  }

  List<WalletDefinition> _decodeDefinitionsSection(Object? value) {
    if (value == null) return const [];
    final section = _object(value);
    _expectVersion(
      _int(section, 'version'),
      WalletDefinitionsCodec.currentVersion,
    );
    final definitions = _definitions.decode(jsonEncode(section));
    if (definitions.isEmpty) throw _malformed('empty definitions section');
    return definitions;
  }

  WalletMetadataSnapshot? _decodeMetadataSection(Object? value) {
    if (value == null) return null;
    final section = _object(value);
    _expectVersion(_int(section, 'version'), walletMetadataSnapshotVersion);
    return _metadata.decode(jsonEncode(section));
  }

  static Map<String, Object?> _section(String payload) =>
      _object(jsonDecode(payload));

  static void _checkSize(String payload) {
    if (utf8.encode(payload).length > maxPlaintextSizeBytes) {
      throw const WalletBackupSnapshotCodecException(
        reason: WalletBackupSnapshotCodecFailureReason.tooLarge,
      );
    }
  }
}

void _expectVersion(int version, int expected) {
  if (version > expected) {
    throw WalletBackupSnapshotCodecException(
      reason: WalletBackupSnapshotCodecFailureReason.unsupportedVersion,
      version: version,
    );
  }
  if (version != expected) throw _malformed('version');
}

KeychainManifest _undated(KeychainManifest manifest) => KeychainManifest(
  version: manifest.version,
  parentFingerprint: manifest.parentFingerprint,
  generatedAt: 0,
  entries: manifest.entries,
);

WalletBackupSnapshotCodecException _malformed(String detail) =>
    WalletBackupSnapshotCodecException(
      reason: WalletBackupSnapshotCodecFailureReason.malformed,
      detail: detail,
    );

Map<String, Object?> _object(Object? value) {
  if (value is! Map) throw _malformed('object');
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) throw _malformed('object key');
    result[entry.key as String] = entry.value;
  }
  return result;
}

void _expectKeys(Map<String, Object?> value) {
  final keys = value.keys.toSet();
  if (!keys.containsAll(WalletBackupSnapshotCodec._requiredKeys) ||
      keys.any(
        (key) => !WalletBackupSnapshotCodec._allowedKeys.contains(key),
      )) {
    throw _malformed('envelope fields');
  }
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw _malformed(key);
}

int _int(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw _malformed(key);
}

Fingerprint _fingerprint(String value) {
  final parsed = Fingerprint.tryParse(value.trim());
  if (parsed == null) throw _malformed('parentFingerprint');
  return parsed;
}
