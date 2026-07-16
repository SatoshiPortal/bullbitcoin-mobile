import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_encryption_key.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:bip85_entropy/bip85_entropy.dart';
import 'package:hex/hex.dart';

const _walletMetadataEncryptionReservationId = 'wallet_metadata_encryption_key';

final class WalletMetadataKeyDerivationException implements Exception {
  final String message;
  final Object? cause;

  const WalletMetadataKeyDerivationException(this.message, {this.cause});

  @override
  String toString() => 'WalletMetadataKeyDerivationException: $message';
}

final class WalletMetadataKeyDeriver {
  static final _fingerprintPattern = RegExp(r'^[0-9a-f]{8}$');

  final Bip85RegistryFacade registry;

  const WalletMetadataKeyDeriver({this.registry = const Bip85RegistryFacade()});

  WalletMetadataEncryptionKey deriveEncryptionKey({
    required String xprvBase58,
    required String expectedParentFingerprint,
  }) {
    try {
      final expected = expectedParentFingerprint.trim().toLowerCase();
      if (!_fingerprintPattern.hasMatch(expected)) {
        throw const WalletMetadataKeyDerivationException(
          'wallet metadata parent fingerprint is invalid',
        );
      }
      final actual = bip32.Bip32Keys.fromBase58(xprvBase58).fingerprintHex;
      if (actual != expected) {
        throw const WalletMetadataKeyDerivationException(
          'wallet metadata xprv does not match parent fingerprint',
        );
      }

      final reservation = _encryptionReservation();
      final entropy = Bip85Entropy.derive(
        xprvBase58: xprvBase58,
        application: CustomApplication.fromNumber(
          reservation.application.number,
        ),
        path: _registryRelativePath(reservation),
      );
      return WalletMetadataEncryptionKey(HEX.encode(entropy.sublist(0, 32)));
    } on WalletMetadataKeyDerivationException {
      rethrow;
    } on ArgumentError catch (e) {
      throw WalletMetadataKeyDerivationException(
        'failed to derive wallet metadata encryption key',
        cause: e,
      );
    } on Exception catch (e) {
      throw WalletMetadataKeyDerivationException(
        'failed to derive wallet metadata encryption key',
        cause: e,
      );
    }
  }

  Bip85Reservation _encryptionReservation() {
    final reservation = registry.reservationById(
      _walletMetadataEncryptionReservationId,
    );
    if (reservation == null ||
        reservation.owner != Bip85ReservationOwner.walletMetadataBackup ||
        reservation.purpose != Bip85ReservationPurpose.manifestEncryptionKey) {
      throw const WalletMetadataKeyDerivationException(
        'wallet metadata encryption reservation is invalid',
      );
    }
    return reservation;
  }

  String _registryRelativePath(Bip85Reservation reservation) {
    final prefix = "${reservation.application.number}'/";
    if (!reservation.scope.exactPath.startsWith(prefix)) {
      throw const WalletMetadataKeyDerivationException(
        'wallet metadata encryption reservation path is invalid',
      );
    }
    return reservation.scope.exactPath.substring(prefix.length);
  }
}
