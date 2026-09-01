import 'package:bb_mobile/core/bip85/domain/bip85_reservations.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:primitives/primitives.dart';

typedef DecodeKeychainManifestFile =
    Result<KeychainManifest, KeychainManifestFailure> Function(String payload);

final class ParseKeychainManifestFileUsecase {
  final DecodeKeychainManifestFile _decode;

  const ParseKeychainManifestFileUsecase(this._decode);

  Result<KeychainManifest, KeychainManifestFailure> execute(
    String payload, {
    required Fingerprint expectedParentFingerprint,
    bool allowEmpty = false,
  }) => switch (_decode(payload)) {
    Err(:final failure) => Err(failure),
    Ok(:final value) => _validate(
      value,
      expectedParentFingerprint: expectedParentFingerprint,
      allowEmpty: allowEmpty,
    ),
  };

  Result<KeychainManifest, KeychainManifestFailure> _validate(
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
    return Ok(manifest);
  }

  bool _validReservation(KeychainManifestEntry entry) {
    if (entry.derivationKind == KeychainManifestDerivationKind.bip32) {
      return entry.materializations.every(
        (item) =>
            item is KeychainManifestWallet &&
            (item.provenance == WalletProvenance.defaultSeed ||
                item.provenance == WalletProvenance.defaultSeedPassphrase ||
                item.provenance == WalletProvenance.importedMnemonic) &&
            (item.provenance != WalletProvenance.defaultSeed ||
                item.childSeedFingerprint == entry.parentFingerprint),
      );
    }
    final reservation = Bip85Reservations.reservationByExactPath(
      entry.derivationPath,
    );
    final userKey = Bip85Reservations.isNostrUserKeyPath(entry.derivationPath);
    if (reservation == null && !userKey) return false;
    if (userKey) {
      return entry.materializations.every(
        (item) =>
            item is KeychainManifestNostrKey &&
            item.keyKind == KeychainManifestNostrKeyKind.userGenerated,
      );
    }
    return switch (reservation!.purpose) {
      Bip85ReservationPurpose.walletSeed => entry.materializations.every(
        (item) =>
            item is KeychainManifestWallet &&
            item.provenance == WalletProvenance.bip85,
      ),
      Bip85ReservationPurpose.nonWalletNostrKey => entry.materializations.every(
        (item) =>
            item is KeychainManifestNostrKey &&
            item.keyKind == KeychainManifestNostrKeyKind.reserved,
      ),
      Bip85ReservationPurpose.backupEncryptionKey => false,
    };
  }
}
