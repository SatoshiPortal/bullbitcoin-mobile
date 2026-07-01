import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_file.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_import.dart';

class ParseKeychainManifestFileUsecase {
  final Bip85RegistryFacade registry;

  const ParseKeychainManifestFileUsecase({
    this.registry = const Bip85RegistryFacade(),
  });

  KeychainManifestImportPlan execute(KeychainManifestFile manifestFile) {
    final entries = manifestFile.entries
        .map(_entryIntent)
        .toList(growable: false);
    return KeychainManifestImportPlan(
      parentFingerprint: manifestFile.parentFingerprint,
      entries: entries,
    );
  }

  KeychainManifestImportEntryIntent _entryIntent(
    KeychainManifestFileEntry entry,
  ) {
    final reservation = registry.reservationById(entry.reservationId);
    if (reservation == null) {
      throw KeychainManifestFileParseException(
        reason: KeychainManifestFileParseFailureReason.unknownReservation,
      );
    }
    if (!reservation.scope.matchesExactPath(entry.bip85DerivationPath)) {
      throw KeychainManifestFileParseException(
        reason: KeychainManifestFileParseFailureReason.invalidMetadata,
      );
    }
    if (reservation.owner.name != entry.ownerFeature ||
        reservation.purpose.name != entry.entryType ||
        reservation.application.number != entry.bip85Application ||
        reservation.scope.segmentValue('index') != entry.bip85Index) {
      throw KeychainManifestFileParseException(
        reason: KeychainManifestFileParseFailureReason.invalidMetadata,
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
    // Duplicate entry ids and wallet ids are rejected by the
    // KeychainManifestFile entity when the payload is decoded, so every
    // materialization reaching this point is unique.
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
