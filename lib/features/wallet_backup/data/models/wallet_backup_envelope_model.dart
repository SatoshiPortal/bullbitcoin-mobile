import 'dart:convert';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_envelope.dart';

enum WalletBackupEnvelopeCodecFailureReason {
  malformed,
  nonCanonical,
  unsupportedEnvelopeVersion,
  unsupportedSection,
  parentFingerprintMismatch,
  tooLarge,
}

final class WalletBackupEnvelopeCodecException implements Exception {
  final WalletBackupEnvelopeCodecFailureReason reason;
  final String message;
  final int? version;
  final String? sectionId;
  final Object? cause;

  const WalletBackupEnvelopeCodecException({
    required this.reason,
    required this.message,
    this.version,
    this.sectionId,
    this.cause,
  });
}

final class WalletBackupEnvelopeCodec {
  static const manifestSectionId = 'keychain_manifest';
  static const definitionsSectionId = 'wallet_definitions';
  static const metadataSectionId = 'wallet_metadata';

  /// RecoverBull adds a 16-byte nonce, up to 16 bytes of AES-CBC padding, and
  /// a 32-byte HMAC. Leaving 64 bytes ensures the decoded ciphertext remains
  /// within Bullnym's 2 MiB object limit.
  static const maxPlaintextSizeBytes = 2 * 1024 * 1024 - 64;

  const WalletBackupEnvelopeCodec();

  String encode(WalletBackupEnvelope envelope) {
    final model = WalletBackupEnvelopeModel.fromEntity(envelope);
    final encoded = jsonEncode(model.toJson());
    _checkSize(encoded);
    return encoded;
  }

  WalletBackupEnvelope decode(
    String payload, {
    required String expectedParentFingerprint,
  }) {
    _checkSize(payload);
    final Object? json;
    try {
      json = jsonDecode(payload);
    } on FormatException catch (error) {
      throw WalletBackupEnvelopeCodecException(
        reason: WalletBackupEnvelopeCodecFailureReason.malformed,
        message: 'wallet backup envelope must be valid JSON',
        cause: error,
      );
    }
    if (json is! Map) {
      throw const WalletBackupEnvelopeCodecException(
        reason: WalletBackupEnvelopeCodecFailureReason.malformed,
        message: 'wallet backup envelope must be a JSON object',
      );
    }

    final model = WalletBackupEnvelopeModel.fromJson(
      _objectMap(json, 'wallet backup envelope'),
    );
    final envelope = model.toEntity();
    final expected = _normalizeFingerprint(expectedParentFingerprint);
    if (envelope.parentFingerprint != expected) {
      throw const WalletBackupEnvelopeCodecException(
        reason:
            WalletBackupEnvelopeCodecFailureReason.parentFingerprintMismatch,
        message: 'wallet backup belongs to a different parent fingerprint',
      );
    }
    if (jsonEncode(
          model.toJson(canonicalParentFingerprint: envelope.parentFingerprint),
        ) !=
        payload) {
      throw const WalletBackupEnvelopeCodecException(
        reason: WalletBackupEnvelopeCodecFailureReason.nonCanonical,
        message: 'wallet backup envelope must use canonical JSON',
      );
    }
    return envelope;
  }

  static void _checkSize(String payload) {
    if (payload.length > maxPlaintextSizeBytes ||
        utf8.encode(payload).length > maxPlaintextSizeBytes) {
      throw const WalletBackupEnvelopeCodecException(
        reason: WalletBackupEnvelopeCodecFailureReason.tooLarge,
        message: 'wallet backup envelope is too large',
      );
    }
  }
}

final class WalletBackupEnvelopeModel {
  static const _topLevelKeys = {
    'version',
    'contentType',
    'parentFingerprint',
    'createdAt',
    'sections',
  };
  static const _manifestSectionKeys = {'version', 'payload'};
  static const _definitionsSectionKeys = {'version', 'payload'};
  static const _metadataSectionKeys = {'version', 'payload'};

  final int version;
  final String contentType;
  final String parentFingerprint;
  final int createdAt;
  final int manifestVersion;
  final Map<String, Object?> manifestPayload;
  final int? definitionsVersion;
  final String? definitionsPayload;
  final int? metadataVersion;
  final String? metadataPayload;

  const WalletBackupEnvelopeModel({
    required this.version,
    required this.contentType,
    required this.parentFingerprint,
    required this.createdAt,
    required this.manifestVersion,
    required this.manifestPayload,
    required this.definitionsVersion,
    required this.definitionsPayload,
    required this.metadataVersion,
    required this.metadataPayload,
  });

  factory WalletBackupEnvelopeModel.fromEntity(WalletBackupEnvelope envelope) {
    final canonicalManifestPayload = _canonicalizeManifestPayload(
      envelope.manifest.payload,
    );
    if (!envelope.manifest.isCanonical ||
        canonicalManifestPayload != envelope.manifest.payload) {
      throw const WalletBackupEnvelopeCodecException(
        reason: WalletBackupEnvelopeCodecFailureReason.nonCanonical,
        message: 'keychain manifest section payload must use canonical JSON',
      );
    }
    final Object? manifestJson;
    try {
      manifestJson = jsonDecode(canonicalManifestPayload);
    } on FormatException catch (error) {
      throw WalletBackupEnvelopeCodecException(
        reason: WalletBackupEnvelopeCodecFailureReason.malformed,
        message: 'keychain manifest section payload must be valid JSON',
        cause: error,
      );
    }
    if (manifestJson is! Map) {
      throw const WalletBackupEnvelopeCodecException(
        reason: WalletBackupEnvelopeCodecFailureReason.malformed,
        message: 'keychain manifest section payload must be a JSON object',
      );
    }
    final manifestPayload = _objectMap(
      manifestJson,
      'keychain manifest section payload',
    );
    final manifestFingerprint = _string(manifestPayload, 'parentFingerprint');
    if (_normalizeFingerprint(manifestFingerprint) !=
        envelope.parentFingerprint) {
      throw const WalletBackupEnvelopeCodecException(
        reason:
            WalletBackupEnvelopeCodecFailureReason.parentFingerprintMismatch,
        message:
            'keychain manifest section does not match the envelope fingerprint',
      );
    }
    final metadata = envelope.metadata;
    final metadataPayload = metadata?.payload;
    if (metadata != null &&
        (!_isCanonicalJsonObject(metadataPayload!) || !metadata.isCanonical)) {
      throw const WalletBackupEnvelopeCodecException(
        reason: WalletBackupEnvelopeCodecFailureReason.nonCanonical,
        message: 'wallet metadata section payload must use canonical JSON',
      );
    }
    final definitions = envelope.definitions;
    final definitionsPayload = definitions?.payload;
    if (definitions != null &&
        (!_isCanonicalJsonObject(definitionsPayload!) ||
            !definitions.isCanonical)) {
      throw const WalletBackupEnvelopeCodecException(
        reason: WalletBackupEnvelopeCodecFailureReason.nonCanonical,
        message: 'wallet definitions section payload must use canonical JSON',
      );
    }
    return WalletBackupEnvelopeModel(
      version: envelope.version,
      contentType: envelope.contentType,
      parentFingerprint: envelope.parentFingerprint,
      createdAt: envelope.createdAt,
      manifestVersion: envelope.manifest.version,
      manifestPayload: manifestPayload,
      definitionsVersion: definitions?.version,
      definitionsPayload: definitionsPayload,
      metadataVersion: metadata?.version,
      metadataPayload: metadataPayload,
    );
  }

  factory WalletBackupEnvelopeModel.fromJson(Map<String, Object?> json) {
    final version = _int(json, 'version');
    if (version > WalletBackupEnvelope.currentVersion) {
      throw WalletBackupEnvelopeCodecException(
        reason:
            WalletBackupEnvelopeCodecFailureReason.unsupportedEnvelopeVersion,
        message: 'unsupported wallet backup envelope version',
        version: version,
      );
    }
    if (version != WalletBackupEnvelope.currentVersion) {
      throw const WalletBackupEnvelopeCodecException(
        reason: WalletBackupEnvelopeCodecFailureReason.malformed,
        message: 'wallet backup envelope version must be positive and current',
      );
    }
    _requireExactKeys(json, _topLevelKeys, 'wallet backup envelope');
    final contentType = _string(json, 'contentType');
    if (contentType != WalletBackupEnvelope.contentTypeV1) {
      throw const WalletBackupEnvelopeCodecException(
        reason: WalletBackupEnvelopeCodecFailureReason.malformed,
        message: 'unsupported wallet backup content type',
      );
    }

    final sections = _objectMap(json['sections'], 'sections');
    for (final sectionId in sections.keys) {
      if (sectionId != WalletBackupEnvelopeCodec.manifestSectionId &&
          sectionId != WalletBackupEnvelopeCodec.definitionsSectionId &&
          sectionId != WalletBackupEnvelopeCodec.metadataSectionId) {
        throw WalletBackupEnvelopeCodecException(
          reason: WalletBackupEnvelopeCodecFailureReason.unsupportedSection,
          message: 'wallet backup contains an unsupported section',
          sectionId: sectionId,
        );
      }
    }
    final manifest = _objectMap(
      sections[WalletBackupEnvelopeCodec.manifestSectionId],
      WalletBackupEnvelopeCodec.manifestSectionId,
    );
    final manifestVersion = _int(manifest, 'version');
    if (manifestVersion != WalletBackupManifestSection.currentVersion) {
      throw WalletBackupEnvelopeCodecException(
        reason: WalletBackupEnvelopeCodecFailureReason.unsupportedSection,
        message: 'unsupported keychain manifest section version',
        sectionId: WalletBackupEnvelopeCodec.manifestSectionId,
        version: manifestVersion,
      );
    }
    _requireExactKeys(
      manifest,
      _manifestSectionKeys,
      WalletBackupEnvelopeCodec.manifestSectionId,
    );

    final definitionsValue =
        sections[WalletBackupEnvelopeCodec.definitionsSectionId];
    final definitionsMap = definitionsValue == null
        ? null
        : _objectMap(
            definitionsValue,
            WalletBackupEnvelopeCodec.definitionsSectionId,
          );
    final definitionsVersion = definitionsMap == null
        ? null
        : _int(definitionsMap, 'version');
    if (definitionsVersion != null &&
        definitionsVersion != WalletBackupDefinitionsSection.currentVersion) {
      throw WalletBackupEnvelopeCodecException(
        reason: WalletBackupEnvelopeCodecFailureReason.unsupportedSection,
        message: 'unsupported wallet definitions section version',
        sectionId: WalletBackupEnvelopeCodec.definitionsSectionId,
        version: definitionsVersion,
      );
    }
    final definitionsPayload = definitionsMap == null
        ? null
        : jsonEncode(
            _objectMap(
              definitionsMap['payload'],
              'wallet definitions section payload',
            ),
          );
    if (definitionsMap != null) {
      _requireExactKeys(
        definitionsMap,
        _definitionsSectionKeys,
        WalletBackupEnvelopeCodec.definitionsSectionId,
      );
      if (!_isCanonicalJsonObject(definitionsPayload!)) {
        throw const WalletBackupEnvelopeCodecException(
          reason: WalletBackupEnvelopeCodecFailureReason.nonCanonical,
          message: 'wallet definitions section payload must use canonical JSON',
        );
      }
    }

    final metadata = sections[WalletBackupEnvelopeCodec.metadataSectionId];
    final metadataVersion = metadata == null
        ? null
        : _int(
            _objectMap(metadata, WalletBackupEnvelopeCodec.metadataSectionId),
            'version',
          );
    final metadataPayload = metadata == null
        ? null
        : jsonEncode(
            _objectMap(
              _objectMap(
                metadata,
                WalletBackupEnvelopeCodec.metadataSectionId,
              )['payload'],
              'wallet metadata section payload',
            ),
          );
    if (metadata != null) {
      final metadataMap = _objectMap(
        metadata,
        WalletBackupEnvelopeCodec.metadataSectionId,
      );
      _requireExactKeys(
        metadataMap,
        _metadataSectionKeys,
        WalletBackupEnvelopeCodec.metadataSectionId,
      );
      if (metadataVersion != WalletBackupMetadataSection.currentVersion) {
        throw WalletBackupEnvelopeCodecException(
          reason: WalletBackupEnvelopeCodecFailureReason.unsupportedSection,
          message: 'unsupported wallet metadata section version',
          sectionId: WalletBackupEnvelopeCodec.metadataSectionId,
          version: metadataVersion,
        );
      }
      if (!_isCanonicalJsonObject(metadataPayload!)) {
        throw const WalletBackupEnvelopeCodecException(
          reason: WalletBackupEnvelopeCodecFailureReason.nonCanonical,
          message: 'wallet metadata section payload must use canonical JSON',
        );
      }
    }

    return WalletBackupEnvelopeModel(
      version: version,
      contentType: contentType,
      parentFingerprint: _string(json, 'parentFingerprint'),
      createdAt: _int(json, 'createdAt'),
      manifestVersion: manifestVersion,
      manifestPayload: _objectMap(
        manifest['payload'],
        'keychain manifest section payload',
      ),
      definitionsVersion: definitionsVersion,
      definitionsPayload: definitionsPayload,
      metadataVersion: metadataVersion,
      metadataPayload: metadataPayload,
    );
  }

  WalletBackupEnvelope toEntity() {
    final normalizedEnvelopeFingerprint = _normalizeFingerprint(
      parentFingerprint,
    );
    final manifestFingerprint = _normalizeFingerprint(
      _string(manifestPayload, 'parentFingerprint'),
    );
    if (manifestFingerprint != normalizedEnvelopeFingerprint) {
      throw const WalletBackupEnvelopeCodecException(
        reason:
            WalletBackupEnvelopeCodecFailureReason.parentFingerprintMismatch,
        message:
            'keychain manifest section does not match the envelope fingerprint',
      );
    }
    try {
      final manifestPayload = jsonEncode(this.manifestPayload);
      final canonicalManifestPayload = _canonicalizeManifestPayload(
        manifestPayload,
      );
      return WalletBackupEnvelope(
        version: version,
        contentType: contentType,
        parentFingerprint: normalizedEnvelopeFingerprint,
        createdAt: createdAt,
        manifest: WalletBackupManifestSection(
          version: manifestVersion,
          payload: manifestPayload,
          parentFingerprint: manifestFingerprint,
          isCanonical: canonicalManifestPayload == manifestPayload,
        ),
        definitions: definitionsPayload == null
            ? null
            : WalletBackupDefinitionsSection(
                version: definitionsVersion!,
                payload: definitionsPayload!,
                isCanonical: _isCanonicalJsonObject(definitionsPayload!),
              ),
        metadata: metadataPayload == null
            ? null
            : WalletBackupMetadataSection(
                version: metadataVersion!,
                payload: metadataPayload!,
                parentFingerprint: normalizedEnvelopeFingerprint,
                isCanonical: _isCanonicalJsonObject(metadataPayload!),
              ),
      );
    } on ArgumentError catch (error) {
      throw WalletBackupEnvelopeCodecException(
        reason: WalletBackupEnvelopeCodecFailureReason.malformed,
        message: 'wallet backup envelope fields are invalid',
        cause: error,
      );
    }
  }

  Map<String, Object?> toJson({String? canonicalParentFingerprint}) => {
    'version': version,
    'contentType': contentType,
    'parentFingerprint': canonicalParentFingerprint ?? parentFingerprint,
    'createdAt': createdAt,
    'sections': {
      WalletBackupEnvelopeCodec.manifestSectionId: {
        'version': manifestVersion,
        'payload': manifestPayload,
      },
      if (definitionsPayload != null)
        WalletBackupEnvelopeCodec.definitionsSectionId: {
          'version': definitionsVersion,
          'payload': jsonDecode(definitionsPayload!),
        },
      if (metadataPayload != null)
        WalletBackupEnvelopeCodec.metadataSectionId: {
          'version': metadataVersion,
          'payload': jsonDecode(metadataPayload!),
        },
    },
  };
}

bool _isCanonicalJsonObject(String payload) {
  try {
    final value = jsonDecode(payload);
    return value is Map && jsonEncode(value) == payload;
  } on FormatException {
    return false;
  }
}

Map<String, Object?> _objectMap(Object? value, String description) {
  if (value is! Map) {
    throw WalletBackupEnvelopeCodecException(
      reason: WalletBackupEnvelopeCodecFailureReason.malformed,
      message: '$description must be a JSON object',
    );
  }
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw WalletBackupEnvelopeCodecException(
        reason: WalletBackupEnvelopeCodecFailureReason.malformed,
        message: '$description must use string keys',
      );
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}

void _requireExactKeys(
  Map<String, Object?> value,
  Set<String> expected,
  String description,
) {
  if (value.length != expected.length || !value.keys.every(expected.contains)) {
    throw WalletBackupEnvelopeCodecException(
      reason: WalletBackupEnvelopeCodecFailureReason.malformed,
      message: '$description contains missing or unknown fields',
    );
  }
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw WalletBackupEnvelopeCodecException(
    reason: WalletBackupEnvelopeCodecFailureReason.malformed,
    message: '$key must be a string',
  );
}

int _int(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw WalletBackupEnvelopeCodecException(
    reason: WalletBackupEnvelopeCodecFailureReason.malformed,
    message: '$key must be an integer',
  );
}

String _normalizeFingerprint(String value) {
  final normalized = value.trim().toLowerCase();
  if (!RegExp(r'^[0-9a-f]{8}$').hasMatch(normalized)) {
    throw const WalletBackupEnvelopeCodecException(
      reason: WalletBackupEnvelopeCodecFailureReason.malformed,
      message: 'parent fingerprint must be 8 hexadecimal characters',
    );
  }
  return normalized;
}

String _canonicalizeManifestPayload(String payload) {
  return switch (canonicalizeKeychainManifestPayload(payload)) {
    Ok(:final value) => value,
    Err(:final failure) => throw WalletBackupEnvelopeCodecException(
      reason: WalletBackupEnvelopeCodecFailureReason.malformed,
      message: 'keychain manifest section payload is invalid',
      cause: failure,
    ),
  };
}
