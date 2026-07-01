import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart';

class KeychainManifestEntry {
  final String entryId;
  final String parentFingerprint;
  final String bip85DerivationPath;
  final String reservationId;
  final String entryType;
  final String ownerFeature;
  final int bip85Application;
  final int bip85Index;
  final int createdAt;
  final int updatedAt;

  KeychainManifestEntry({
    String? entryId,
    required String parentFingerprint,
    required String bip85DerivationPath,
    required this.reservationId,
    required this.entryType,
    required this.ownerFeature,
    required this.bip85Application,
    required this.bip85Index,
    required this.createdAt,
    required this.updatedAt,
  }) : parentFingerprint = KeychainManifestFingerprint.normalize(
         parentFingerprint,
       ),
       bip85DerivationPath = KeychainManifestBip85Path.normalize(
         bip85DerivationPath,
       ),
       entryId =
           entryId ??
           KeychainManifestEntryId.fromIdentity(
             parentFingerprint: parentFingerprint,
             bip85DerivationPath: bip85DerivationPath,
           ) {
    final expectedEntryId = KeychainManifestEntryId.fromIdentity(
      parentFingerprint: this.parentFingerprint,
      bip85DerivationPath: this.bip85DerivationPath,
    );
    if (this.entryId != expectedEntryId) {
      throw KeychainManifestInvalidEntryException(
        'entry id must match parent fingerprint and BIP85 path',
      );
    }
    if (reservationId.trim().isEmpty) {
      throw KeychainManifestInvalidEntryException('reservation id is required');
    }
    if (entryType.trim().isEmpty) {
      throw KeychainManifestInvalidEntryException('entry type is required');
    }
    if (ownerFeature.trim().isEmpty) {
      throw KeychainManifestInvalidEntryException('owner feature is required');
    }
    if (bip85Application < 0 || bip85Index < 0) {
      throw KeychainManifestInvalidEntryException(
        'BIP85 application and index must be non-negative',
      );
    }
    if (createdAt < 0 || updatedAt < 0) {
      throw KeychainManifestInvalidEntryException(
        'timestamps must be non-negative',
      );
    }
  }

  KeychainManifestEntryIdentity get identity => KeychainManifestEntryIdentity(
    parentFingerprint: parentFingerprint,
    bip85DerivationPath: bip85DerivationPath,
  );

  bool sameRecordAs(KeychainManifestEntry other) {
    return entryId == other.entryId &&
        parentFingerprint == other.parentFingerprint &&
        bip85DerivationPath == other.bip85DerivationPath &&
        reservationId == other.reservationId &&
        entryType == other.entryType &&
        ownerFeature == other.ownerFeature &&
        bip85Application == other.bip85Application &&
        bip85Index == other.bip85Index;
  }
}

class KeychainManifestWalletMaterialization {
  final String walletId;
  final String entryId;
  final String childSeedFingerprint;
  final String network;
  final String walletPurpose;
  final String scriptType;
  final int createdAt;
  final int updatedAt;

  KeychainManifestWalletMaterialization({
    required this.walletId,
    required this.entryId,
    required String childSeedFingerprint,
    required this.network,
    required this.walletPurpose,
    required this.scriptType,
    required this.createdAt,
    required this.updatedAt,
  }) : childSeedFingerprint = KeychainManifestFingerprint.normalize(
         childSeedFingerprint,
       ) {
    if (walletId.trim().isEmpty) {
      throw KeychainManifestInvalidEntryException('wallet id is required');
    }
    if (entryId.trim().isEmpty) {
      throw KeychainManifestInvalidEntryException('entry id is required');
    }
    if (network.trim().isEmpty) {
      throw KeychainManifestInvalidEntryException('network is required');
    }
    if (walletPurpose.trim().isEmpty) {
      throw KeychainManifestInvalidEntryException('wallet purpose is required');
    }
    if (scriptType.trim().isEmpty) {
      throw KeychainManifestInvalidEntryException('script type is required');
    }
    if (createdAt < 0 || updatedAt < 0) {
      throw KeychainManifestInvalidEntryException(
        'timestamps must be non-negative',
      );
    }
  }

  bool sameRecordAs(KeychainManifestWalletMaterialization other) {
    return walletId == other.walletId &&
        entryId == other.entryId &&
        childSeedFingerprint == other.childSeedFingerprint &&
        network == other.network &&
        walletPurpose == other.walletPurpose &&
        scriptType == other.scriptType;
  }
}

class KeychainManifestWalletMaterializationRecord {
  final KeychainManifestEntry entry;
  final KeychainManifestWalletMaterialization walletMaterialization;

  const KeychainManifestWalletMaterializationRecord({
    required this.entry,
    required this.walletMaterialization,
  });

  String get walletId => walletMaterialization.walletId;
  KeychainManifestEntryIdentity get identity => entry.identity;

  bool sameRecordAs(KeychainManifestWalletMaterializationRecord other) {
    return entry.sameRecordAs(other.entry) &&
        walletMaterialization.sameRecordAs(other.walletMaterialization);
  }
}

class KeychainManifestEntryIdentity {
  final String parentFingerprint;
  final String bip85DerivationPath;

  KeychainManifestEntryIdentity({
    required String parentFingerprint,
    required String bip85DerivationPath,
  }) : parentFingerprint = KeychainManifestFingerprint.normalize(
         parentFingerprint,
       ),
       bip85DerivationPath = KeychainManifestBip85Path.normalize(
         bip85DerivationPath,
       );

  String get entryId => KeychainManifestEntryId.fromIdentity(
    parentFingerprint: parentFingerprint,
    bip85DerivationPath: bip85DerivationPath,
  );
}

class KeychainManifestEntryId {
  const KeychainManifestEntryId._();

  static String fromIdentity({
    required String parentFingerprint,
    required String bip85DerivationPath,
  }) {
    final fingerprint = KeychainManifestFingerprint.normalize(
      parentFingerprint,
    );
    final path = KeychainManifestBip85Path.normalize(bip85DerivationPath);
    return '$fingerprint:$path';
  }
}

class KeychainManifestFingerprint {
  static final _pattern = RegExp(r'^[0-9a-fA-F]{8}$');

  const KeychainManifestFingerprint._();

  static String normalize(String value) {
    final normalized = value.trim().toLowerCase();
    if (!_pattern.hasMatch(normalized)) {
      throw KeychainManifestInvalidEntryException(
        'fingerprint must be 8 hex characters',
      );
    }
    return normalized;
  }
}

class KeychainManifestBip85Path {
  static final _pattern = RegExp(r"^[0-9]+'(?:/[0-9]+')+$");
  static final _segmentPattern = RegExp(r"([0-9]+)'");

  const KeychainManifestBip85Path._();

  static String normalize(String value) {
    final normalized = value.trim();
    if (!_pattern.hasMatch(normalized)) {
      throw KeychainManifestInvalidEntryException(
        'BIP85 path must be a registry-relative hardened path',
      );
    }
    final segments = <String>[];
    for (final match in _segmentPattern.allMatches(normalized)) {
      final segment = int.tryParse(match.group(1)!);
      if (segment == null || segment < 0 || segment > 0x7fffffff) {
        throw KeychainManifestInvalidEntryException(
          'BIP85 path segment is invalid',
        );
      }
      segments.add("$segment'");
    }
    return segments.join('/');
  }
}
