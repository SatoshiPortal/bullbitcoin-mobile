import 'dart:convert';

import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_file.dart';

class KeychainManifestFileCodec {
  const KeychainManifestFileCodec();

  String encode(KeychainManifestFile manifestFile) {
    return jsonEncode(_manifestToJson(manifestFile));
  }

  Map<String, Object?> _manifestToJson(KeychainManifestFile manifestFile) {
    return {
      'version': manifestFile.version,
      'parentFingerprint': manifestFile.parentFingerprint,
      'generatedAt': manifestFile.generatedAt,
      'updatedAt': manifestFile.updatedAt,
      'entries': manifestFile.entries.map(_entryToJson).toList(growable: false),
    };
  }

  Map<String, Object?> _entryToJson(KeychainManifestFileEntry entry) {
    return {
      'entryId': entry.entryId,
      'bip85DerivationPath': entry.bip85DerivationPath,
      'reservationId': entry.reservationId,
      'entryType': entry.entryType,
      'ownerFeature': entry.ownerFeature,
      'bip85Application': entry.bip85Application,
      'bip85Index': entry.bip85Index,
      'createdAt': entry.createdAt,
      'updatedAt': entry.updatedAt,
      'materializations': entry.materializations
          .map(_materializationToJson)
          .toList(growable: false),
    };
  }

  Map<String, Object?> _materializationToJson(
    KeychainManifestFileWalletMaterialization materialization,
  ) {
    return {
      'type': KeychainManifestFileWalletMaterialization.type,
      'walletId': materialization.walletId,
      'childSeedFingerprint': materialization.childSeedFingerprint,
      'network': materialization.network,
      'scriptType': materialization.scriptType,
      'createdAt': materialization.createdAt,
      'updatedAt': materialization.updatedAt,
    };
  }
}
