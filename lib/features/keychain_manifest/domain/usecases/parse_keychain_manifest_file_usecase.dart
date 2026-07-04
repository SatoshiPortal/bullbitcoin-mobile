import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_entry.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_file.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_file_decoder.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_import.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_reservation_support.dart';

class ParseKeychainManifestFileUsecase {
  final KeychainManifestFileDecoder _codec;
  final Bip85RegistryFacade _bip85Registry;

  const ParseKeychainManifestFileUsecase({
    required this._codec,
    required this._bip85Registry,
  });

  KeychainManifestImportPlan execute(
    String payload, {
    required String expectedParentFingerprint,
    bool allowEmpty = false,
  }) {
    final manifestFile = _codec.decode(payload);
    // The fingerprint gate runs before any registry validation: a manifest
    // for another parent seed must be refused regardless of its contents.
    final normalizedExpectedParentFingerprint =
        KeychainManifestFingerprint.normalize(expectedParentFingerprint);
    if (manifestFile.parentFingerprint != normalizedExpectedParentFingerprint) {
      throw KeychainManifestFileParseException(
        reason: KeychainManifestFileParseFailureReason.wrongParentFingerprint,
      );
    }
    // Mirrors the export gate: an empty plan carries no recoverable
    // inventory, so returning one silently must be an explicit caller
    // decision.
    if (manifestFile.entries.isEmpty && !allowEmpty) {
      throw KeychainManifestEmptyInventoryException();
    }
    // Every valid entry maps to a distinct registry reservation, so a file
    // with more entries than reservations can never validate; bound the
    // work before per-entry validation.
    if (manifestFile.entries.length > _bip85Registry.reservations.length) {
      throw KeychainManifestFileParseException(
        reason: KeychainManifestFileParseFailureReason.invalidMetadata,
      );
    }
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
    final reservation = _bip85Registry.reservationById(entry.reservationId);
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
    // V1 wallet manifest files carry wallet-seed reservations only, so the
    // support gate also proves the wallet-seed scope shape (and its typed
    // wallet index).
    if (reservation is! Bip85WalletSeedReservation ||
        !_supportsWalletManifestImport(reservation)) {
      throw KeychainManifestFileParseException(
        reason: KeychainManifestFileParseFailureReason.invalidMetadata,
      );
    }
    if (reservation.owner.name != entry.ownerFeature ||
        reservation.purpose.name != entry.entryType ||
        reservation.application.number != entry.bip85Application ||
        reservation.walletIndex != entry.bip85Index) {
      throw KeychainManifestFileParseException(
        reason: KeychainManifestFileParseFailureReason.invalidMetadata,
      );
    }
    return KeychainManifestImportEntryIntent.fromFileEntry(
      entry,
      walletMaterializations: _walletMaterializations(entry),
    );
  }

  bool _supportsWalletManifestImport(Bip85Reservation reservation) {
    // Import plans cover every EXPORTABLE product (100/101/102) so the frozen
    // v1 format can round-trip all of them; recovery separately decides which
    // are materialized (R2-KC3/F1b, ruling A/B).
    return KeychainManifestReservationSupport.supportsV1Export(reservation);
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
