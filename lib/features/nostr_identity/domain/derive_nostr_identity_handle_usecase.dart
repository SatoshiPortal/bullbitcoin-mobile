import 'package:bb_mobile/core/nostr/nostr_keychain_handle.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';

const _walletManifestReservationId = 'nostr_wallet_manifest_key';
const _bullnymServerAuthReservationId = 'nostr_bullnym_server_auth_key';
const _bullnymNip05VerificationReservationId =
    'nostr_nip05_public_nym_verification_key';
const _walletMetadataReservationId = 'wallet_metadata_signing_key';

enum NostrIdentityRole {
  walletManifest,
  bullnymServerAuth,
  bullnymNip05Verification,
  walletMetadata,
}

class DeriveNostrIdentityHandleUsecase {
  final Bip85RegistryFacade _registry;

  const DeriveNostrIdentityHandleUsecase({required this._registry});

  NostrKeychainHandle execute({
    required String xprvBase58,
    required NostrIdentityRole role,
  }) {
    return _deriveFromReservation(
      xprvBase58: xprvBase58,
      reservationId: _reservationIdForRole(role),
    );
  }

  String _reservationIdForRole(NostrIdentityRole role) {
    return switch (role) {
      NostrIdentityRole.walletManifest => _walletManifestReservationId,
      NostrIdentityRole.bullnymServerAuth => _bullnymServerAuthReservationId,
      NostrIdentityRole.bullnymNip05Verification =>
        _bullnymNip05VerificationReservationId,
      NostrIdentityRole.walletMetadata => _walletMetadataReservationId,
    };
  }

  NostrKeychainHandle _deriveFromReservation({
    required String xprvBase58,
    required String reservationId,
  }) {
    final reservation = _registry.reservationById(reservationId);
    if (reservation == null) {
      throw StateError('Unknown Nostr BIP85 reservation: $reservationId');
    }
    _validateReservation(reservation, reservationId);
    return NostrKeychainHandle.deriveFromBip85Path(
      xprvBase58: xprvBase58,
      hardenedPath: reservation.scope.exactPath,
    );
  }

  void _validateReservation(
    Bip85Reservation reservation,
    String reservationId,
  ) {
    if (reservation is! Bip85KeyReservation) {
      throw StateError('Expected a key-shaped BIP85 signing reservation');
    }
    if (reservation.application.number != nostrBip85Application) {
      throw StateError(
        'Expected BIP340 application $nostrBip85Application, '
        'got ${reservation.application.number}',
      );
    }
    if (reservationId == _walletMetadataReservationId) {
      if (reservation.owner != Bip85ReservationOwner.walletMetadataBackup ||
          reservation.purpose != Bip85ReservationPurpose.backupSigningKey) {
        throw StateError('Expected a wallet-metadata signing reservation');
      }
      return;
    }
    if (reservation.owner != Bip85ReservationOwner.nostr ||
        reservation.purpose != Bip85ReservationPurpose.nonWalletNostrKey) {
      throw StateError('Expected a Nostr-owned BIP85 reservation');
    }
  }
}
