import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_reservations.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/backup_identity_record.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/backup_wallet.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/nostr_key_record.dart';

final class KeychainManifest {
  final String sourceFingerprint;
  final List<BackupWallet> wallets;
  final List<Bip85DerivationEntity> derivations;
  final List<NostrKeyRecord> nostrKeys;
  final List<BackupIdentityRecord> backupIdentities;

  KeychainManifest({
    required this.sourceFingerprint,
    required List<BackupWallet> wallets,
    required List<Bip85DerivationEntity> derivations,
    required List<NostrKeyRecord> nostrKeys,
    required List<BackupIdentityRecord> backupIdentities,
  }) : wallets = List.unmodifiable(wallets),
       derivations = List.unmodifiable(derivations),
       nostrKeys = List.unmodifiable(nostrKeys),
       backupIdentities = List.unmodifiable(backupIdentities) {
    if (!RegExp(r'^[0-9a-f]{8}$').hasMatch(sourceFingerprint) ||
        wallets.map((wallet) => wallet.reference).toSet().length !=
            wallets.length ||
        nostrKeys.any((key) => key.parentFingerprint != sourceFingerprint) ||
        nostrKeys.map((key) => key.identity).toSet().length !=
            nostrKeys.length ||
        derivations.any(
          (entry) =>
              entry.xprvFingerprint != sourceFingerprint ||
              Bip85Reservations.isReservedPath(entry.path),
        ) ||
        derivations.map((entry) => entry.path).toSet().length !=
            derivations.length ||
        backupIdentities.length != 2 ||
        backupIdentities.map((entry) => entry.kind).toSet().length != 2 ||
        backupIdentities.map((entry) => entry.publicKey).toSet().length != 2 ||
        backupIdentities.any(
          (entry) => entry.parentFingerprint != sourceFingerprint,
        )) {
      throw const FormatException('Inconsistent recovery inventory');
    }
  }
}

/// References connect facts within one backup. Recovery resolves them to the
/// target installation; the source IDs do not dictate target database IDs.
final class CapturedKeychainManifest {
  final KeychainManifest manifest;
  final Map<String, String> walletReferences;

  CapturedKeychainManifest({
    required this.manifest,
    required Map<String, String> walletReferences,
  }) : walletReferences = Map.unmodifiable(walletReferences);
}
