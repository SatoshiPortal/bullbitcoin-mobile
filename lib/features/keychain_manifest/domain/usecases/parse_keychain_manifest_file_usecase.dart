import 'package:bb_mobile/core/bip85/domain/bip85_reservations.dart';
import 'package:bb_mobile/features/keychain_manifest/data/models/keychain_manifest_file_model.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:primitives/primitives.dart';

final class ParseKeychainManifestFileUsecase {
  final KeychainManifestFileCodec _codec;

  const ParseKeychainManifestFileUsecase(this._codec);

  Result<KeychainManifestImportPlan, KeychainManifestFailure> execute(
    String payload, {
    required Fingerprint expectedParentFingerprint,
    bool allowEmpty = false,
  }) => switch (_codec.decode(payload)) {
    Err(:final failure) => Err(failure),
    Ok(:final value) => validate(
      value,
      expectedParentFingerprint: expectedParentFingerprint,
      allowEmpty: allowEmpty,
    ),
  };

  Result<KeychainManifestImportPlan, KeychainManifestFailure> validate(
    KeychainManifest manifest, {
    required Fingerprint expectedParentFingerprint,
    bool allowEmpty = false,
  }) {
    if (manifest.parentFingerprint != expectedParentFingerprint) {
      return const Err(KeychainManifestParentMismatchFailure());
    }
    if (manifest.entries.isEmpty && !allowEmpty) {
      return const Err(KeychainManifestEmptyFailure());
    }
    for (final entry in manifest.entries) {
      if (!_validReservation(entry)) {
        return const Err(KeychainManifestUnknownReservationFailure());
      }
    }
    return Ok(KeychainManifestImportPlan(manifest));
  }

  bool _validReservation(KeychainManifestEntry entry) {
    final reservation = Bip85Reservations.reservationById(entry.reservationId);
    final userKey =
        entry.reservationId == Bip85Reservations.nostrUserKeyReservationId &&
        Bip85Reservations.isNostrUserKeyPath(entry.bip85DerivationPath);
    if (reservation == null && !userKey) return false;
    if (userKey) {
      return entry.ownerFeature == 'nostr' &&
          entry.entryType == 'userGenerated' &&
          entry.bip85Application == Bip85Reservations.nostrApplicationNumber &&
          entry.bip85Index == Bip85Reservations.nostrUserAccount &&
          entry.materializations.every(
            (item) =>
                item is KeychainManifestNostrKey &&
                item.keyKind == KeychainManifestNostrKeyKind.userGenerated,
          );
    }
    if (entry.bip85DerivationPath != reservation!.path ||
        entry.ownerFeature != reservation.owner.name ||
        entry.entryType != reservation.purpose.name ||
        entry.bip85Application != reservation.application) {
      return false;
    }
    return switch (reservation.purpose) {
      Bip85ReservationPurpose.walletSeed =>
        entry.bip85Index == reservation.index &&
            entry.materializations.every(
              (item) => item is KeychainManifestWallet,
            ),
      Bip85ReservationPurpose.nonWalletNostrKey =>
        entry.bip85Index == Bip85Reservations.nostrUserAccount &&
            entry.materializations.every(
              (item) =>
                  item is KeychainManifestNostrKey &&
                  item.keyKind == KeychainManifestNostrKeyKind.reserved,
            ),
      Bip85ReservationPurpose.backupEncryptionKey => false,
    };
  }
}
