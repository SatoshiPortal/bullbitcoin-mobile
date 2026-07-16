import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_entry.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_encryption.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:bip85_entropy/bip85_entropy.dart';
import 'package:hex/hex.dart';

const _manifestEncryptionReservationId = 'keychain_manifest_encryption_key';

final class DeriveKeychainManifestEncryptionKeyUsecase {
  final Bip85RegistryFacade registry;

  const DeriveKeychainManifestEncryptionKeyUsecase([
    this.registry = const Bip85RegistryFacade(),
  ]);

  KeychainManifestEncryptionKey execute({
    required String xprvBase58,
    required String expectedParentFingerprint,
  }) {
    try {
      final expected = KeychainManifestFingerprint.normalize(
        expectedParentFingerprint,
      );
      final actual = bip32.Bip32Keys.fromBase58(xprvBase58).fingerprintHex;
      if (actual != expected) {
        throw KeychainManifestEncryptionException(
          'manifest encryption xprv does not match parent fingerprint',
        );
      }

      final reservation = registry.reservationById(
        _manifestEncryptionReservationId,
      );
      if (reservation == null ||
          reservation.owner != Bip85ReservationOwner.keychainManifest ||
          reservation.purpose !=
              Bip85ReservationPurpose.manifestEncryptionKey) {
        throw KeychainManifestEncryptionException(
          'manifest encryption reservation is missing or invalid',
        );
      }
      final prefix = "${reservation.application.number}'/";
      if (!reservation.scope.exactPath.startsWith(prefix)) {
        throw KeychainManifestEncryptionException(
          'manifest encryption reservation path is invalid',
        );
      }
      final derivation = Bip85Entropy.derive(
        xprvBase58: xprvBase58,
        application: CustomApplication.fromNumber(
          reservation.application.number,
        ),
        path: reservation.scope.exactPath.substring(prefix.length),
      );
      return KeychainManifestEncryptionKey(
        HEX.encode(derivation.sublist(0, 32)),
      );
    } on KeychainManifestException {
      rethrow;
    } catch (error) {
      throw KeychainManifestEncryptionException(
        'failed to derive manifest encryption key',
        cause: error,
      );
    }
  }
}
