import 'package:bb_mobile/core/nostr/nostr_keychain_handle.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';

const _walletManifestReservationId = 'nostr_wallet_manifest_key';
const _bullnymServerAuthReservationId = 'nostr_bullnym_server_auth_key';
const _bullnymNip05VerificationReservationId =
    'nostr_nip05_public_nym_verification_key';

enum NostrIdentityRole {
  walletManifest,
  bullnymServerAuth,
  bullnymNip05Verification,
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
    _validateNostrReservation(reservation);
    return NostrKeychainHandle.deriveFromBip85Path(
      xprvBase58: xprvBase58,
      hardenedPath: reservation.scope.exactPath,
    );
  }

  void _validateNostrReservation(Bip85Reservation reservation) {
    // Nostr identity keys are non-wallet key material; the registry models
    // them with the key reservation shape, which carries no wallet index.
    if (reservation is! Bip85KeyReservation) {
      throw StateError('Expected a key-shaped Nostr BIP85 reservation');
    }
    if (reservation.application.number != nostrBip85Application) {
      throw StateError(
        'Expected Nostr BIP85 application $nostrBip85Application, '
        'got ${reservation.application.number}',
      );
    }
    if (reservation.owner != Bip85ReservationOwner.nostr) {
      throw StateError('Expected a Nostr-owned BIP85 reservation');
    }
  }
}
