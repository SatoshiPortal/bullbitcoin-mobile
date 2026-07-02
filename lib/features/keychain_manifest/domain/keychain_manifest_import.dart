import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_entry.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_file.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart';

/// A typed import plan parsed from an unsigned manifest file.
///
/// Parsing validates shape, internal consistency, and registry metadata; it
/// cannot prove the file's claims are true for this device. Fields below are
/// marked VERIFIED (checked against local sources during parsing) or CLAIMED
/// (asserted by the file only — the consumer must verify before acting). See
/// "Consumer obligations" in `keychain_manifest_architecture.md`.
class KeychainManifestImportPlan {
  /// VERIFIED: matched against the caller-supplied expected fingerprint,
  /// which must come from local seed storage.
  final String parentFingerprint;

  final List<KeychainManifestImportEntryIntent> entries;

  KeychainManifestImportPlan({
    required String parentFingerprint,
    required List<KeychainManifestImportEntryIntent> entries,
  }) : parentFingerprint = KeychainManifestFingerprint.normalize(
         parentFingerprint,
       ),
       entries = List.unmodifiable(entries);

  List<KeychainManifestWalletMaterializationIntent>
  get walletMaterializations => entries
      .expand((entry) => entry.walletMaterializations)
      .toList(growable: false);
}

class KeychainManifestImportEntryIntent {
  /// VERIFIED: derived from the verified parent fingerprint and the
  /// registry-validated BIP85 path.
  final String entryId;

  /// VERIFIED: matched against the caller-supplied expected fingerprint.
  final String parentFingerprint;

  /// VERIFIED: matched against the registry reservation's exact path.
  final String bip85DerivationPath;

  /// VERIFIED: resolved against the local BIP85 registry.
  final String reservationId;

  final List<KeychainManifestWalletMaterializationIntent>
  walletMaterializations;

  KeychainManifestImportEntryIntent({
    required this.entryId,
    required String parentFingerprint,
    required String bip85DerivationPath,
    required this.reservationId,
    required List<KeychainManifestWalletMaterializationIntent>
    walletMaterializations,
  }) : parentFingerprint = KeychainManifestFingerprint.normalize(
         parentFingerprint,
       ),
       bip85DerivationPath = KeychainManifestBip85Path.normalize(
         bip85DerivationPath,
       ),
       walletMaterializations = List.unmodifiable(walletMaterializations) {
    if (this.walletMaterializations.isEmpty) {
      throw KeychainManifestInvalidEntryException(
        'manifest import entry requires wallet materializations',
      );
    }
  }

  factory KeychainManifestImportEntryIntent.fromFileEntry(
    KeychainManifestFileEntry entry, {
    required List<KeychainManifestWalletMaterializationIntent>
    walletMaterializations,
  }) {
    return KeychainManifestImportEntryIntent(
      entryId: entry.entryId,
      parentFingerprint: entry.parentFingerprint,
      bip85DerivationPath: entry.bip85DerivationPath,
      reservationId: entry.reservationId,
      walletMaterializations: walletMaterializations,
    );
  }
}

class KeychainManifestWalletMaterializationIntent {
  /// VERIFIED: derived from the verified parent fingerprint and the
  /// registry-validated BIP85 path.
  final String entryId;

  /// VERIFIED: resolved against the local BIP85 registry.
  final String reservationId;

  /// VERIFIED: matched against the registry reservation's exact path.
  final String bip85DerivationPath;

  /// CLAIMED: asserted by the file only. Consumers MUST recompute the wallet
  /// id from the locally derived descriptor and never trust this value.
  final String walletId;

  /// CLAIMED: asserted by the file only. Consumers MUST verify it against
  /// the fingerprint of the locally derived child seed and refuse the
  /// materialization on mismatch.
  final String childSeedFingerprint;

  /// CLAIMED: a known wire value, but whether this binding belongs on this
  /// device (environment/network match) is the consumer's decision.
  final Network network;

  /// CLAIMED: a known wire value; the binding itself is file-claimed.
  final ScriptType scriptType;

  KeychainManifestWalletMaterializationIntent({
    required this.entryId,
    required this.reservationId,
    required String bip85DerivationPath,
    required this.walletId,
    required String childSeedFingerprint,
    required this.network,
    required this.scriptType,
  }) : bip85DerivationPath = KeychainManifestBip85Path.normalize(
         bip85DerivationPath,
       ),
       childSeedFingerprint = KeychainManifestFingerprint.normalize(
         childSeedFingerprint,
       ) {
    if (entryId.trim().isEmpty ||
        reservationId.trim().isEmpty ||
        walletId.trim().isEmpty) {
      throw KeychainManifestInvalidEntryException(
        'manifest import wallet materialization metadata is required',
      );
    }
  }

  factory KeychainManifestWalletMaterializationIntent.fromFileMaterialization({
    required KeychainManifestFileEntry entry,
    required KeychainManifestFileWalletMaterialization materialization,
  }) {
    // Wire values are untrusted file input: gate them against the known enum
    // names before Network.fromName/ScriptType.fromName, whose firstWhere
    // would otherwise escape as an untyped StateError.
    if (!Network.values.any(
      (network) => network.name == materialization.network,
    )) {
      throw KeychainManifestFileParseException(
        reason: KeychainManifestFileParseFailureReason.invalidMetadata,
        cause: const FormatException('unknown manifest wallet network value'),
      );
    }
    if (!ScriptType.values.any(
      (scriptType) => scriptType.name == materialization.scriptType,
    )) {
      throw KeychainManifestFileParseException(
        reason: KeychainManifestFileParseFailureReason.invalidMetadata,
        cause: const FormatException(
          'unknown manifest wallet script type value',
        ),
      );
    }
    return KeychainManifestWalletMaterializationIntent(
      entryId: entry.entryId,
      reservationId: entry.reservationId,
      bip85DerivationPath: entry.bip85DerivationPath,
      walletId: materialization.walletId,
      childSeedFingerprint: materialization.childSeedFingerprint,
      network: Network.fromName(materialization.network),
      scriptType: ScriptType.fromName(materialization.scriptType),
    );
  }
}
