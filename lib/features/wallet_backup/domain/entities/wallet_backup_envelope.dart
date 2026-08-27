final class WalletBackupManifestSection {
  static const currentVersion = 1;

  final int version;
  final String payload;
  final String parentFingerprint;
  final bool isCanonical;

  WalletBackupManifestSection({
    this.version = currentVersion,
    required this.payload,
    required String parentFingerprint,
    this.isCanonical = true,
  }) : parentFingerprint = _normalizeFingerprint(parentFingerprint) {
    if (version != currentVersion) {
      throw ArgumentError.value(
        version,
        'version',
        'unsupported keychain manifest section version',
      );
    }
    if (payload.isEmpty) {
      throw ArgumentError.value(
        payload,
        'payload',
        'keychain manifest section payload is required',
      );
    }
  }
}

final class WalletBackupMetadataSection {
  static const currentVersion = 1;

  final int version;
  final String payload;
  final String parentFingerprint;
  final bool isCanonical;

  WalletBackupMetadataSection({
    this.version = currentVersion,
    required this.payload,
    required String parentFingerprint,
    this.isCanonical = true,
  }) : parentFingerprint = _normalizeFingerprint(parentFingerprint) {
    if (version != currentVersion) {
      throw ArgumentError.value(
        version,
        'version',
        'unsupported wallet metadata section version',
      );
    }
    if (payload.isEmpty) {
      throw ArgumentError.value(
        payload,
        'payload',
        'wallet metadata section payload is required',
      );
    }
  }
}

final class WalletBackupDefinitionsSection {
  static const currentVersion = 1;

  final int version;
  final String payload;
  final bool isCanonical;

  WalletBackupDefinitionsSection({
    this.version = currentVersion,
    required this.payload,
    this.isCanonical = true,
  }) {
    if (version != currentVersion) {
      throw ArgumentError.value(
        version,
        'version',
        'unsupported wallet definitions section version',
      );
    }
    if (payload.isEmpty) {
      throw ArgumentError.value(
        payload,
        'payload',
        'wallet definitions section payload is required',
      );
    }
  }
}

final class WalletBackupEnvelope {
  static const currentVersion = 1;
  static const contentTypeV1 = 'bullbitcoin.wallet_backup.v1';

  final int version;
  final String contentType;
  final String parentFingerprint;
  final int createdAt;
  final WalletBackupManifestSection manifest;
  final WalletBackupDefinitionsSection? definitions;
  final WalletBackupMetadataSection? metadata;

  WalletBackupEnvelope({
    this.version = currentVersion,
    this.contentType = contentTypeV1,
    required String parentFingerprint,
    required this.createdAt,
    required this.manifest,
    this.definitions,
    this.metadata,
  }) : parentFingerprint = _normalizeFingerprint(parentFingerprint) {
    if (version != currentVersion) {
      throw ArgumentError.value(
        version,
        'version',
        'unsupported wallet backup envelope version',
      );
    }
    if (contentType != contentTypeV1) {
      throw ArgumentError.value(
        contentType,
        'contentType',
        'unsupported wallet backup content type',
      );
    }
    if (createdAt < 0) {
      throw ArgumentError.value(
        createdAt,
        'createdAt',
        'wallet backup timestamp must be non-negative',
      );
    }
    if (manifest.parentFingerprint != this.parentFingerprint) {
      throw ArgumentError(
        'wallet backup manifest must match the envelope parent fingerprint',
      );
    }
    if (metadata != null &&
        metadata!.parentFingerprint != this.parentFingerprint) {
      throw ArgumentError(
        'wallet backup metadata must match the envelope parent fingerprint',
      );
    }
  }
}

String _normalizeFingerprint(String value) {
  final normalized = value.trim().toLowerCase();
  if (!RegExp(r'^[0-9a-f]{8}$').hasMatch(normalized)) {
    throw ArgumentError.value(
      value,
      'parentFingerprint',
      'parent fingerprint must be 8 hexadecimal characters',
    );
  }
  return normalized;
}
