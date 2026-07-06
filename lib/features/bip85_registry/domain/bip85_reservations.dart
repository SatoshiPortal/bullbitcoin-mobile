import 'package:bb_mobile/features/bip85_registry/domain/bip85_reservation.dart';

class Bip85Reservations {
  const Bip85Reservations._();

  static final btcpayWalletSeed = Bip85WalletSeedReservation(
    id: 'btcpay_wallet_seed',
    deterministicAlias: 'BTCPay',
    owner: Bip85ReservationOwner.btcpay,
    application: const Bip85ApplicationSpec(number: 39),
    segments: const [
      Bip85PathSegment(name: 'language', value: 0),
      Bip85PathSegment(name: 'words', value: 12),
      Bip85PathSegment(name: 'index', value: 100),
    ],
  );

  static final lightningAddressWalletSeed = Bip85WalletSeedReservation(
    id: 'lightning_address_wallet_seed',
    deterministicAlias: 'Lightning Address',
    owner: Bip85ReservationOwner.lightningAddress,
    application: const Bip85ApplicationSpec(number: 39),
    segments: const [
      Bip85PathSegment(name: 'language', value: 0),
      Bip85PathSegment(name: 'words', value: 12),
      Bip85PathSegment(name: 'index', value: 101),
    ],
  );

  static final paymentPageWalletSeed = Bip85WalletSeedReservation(
    id: 'payment_page_wallet_seed',
    deterministicAlias: 'Payment Page',
    owner: Bip85ReservationOwner.paymentPage,
    application: const Bip85ApplicationSpec(number: 39),
    segments: const [
      Bip85PathSegment(name: 'language', value: 0),
      Bip85PathSegment(name: 'words', value: 12),
      Bip85PathSegment(name: 'index', value: 102),
    ],
  );

  static final posWalletSeed = Bip85WalletSeedReservation(
    id: 'pos_wallet_seed',
    deterministicAlias: 'Point of Sale',
    owner: Bip85ReservationOwner.pos,
    application: const Bip85ApplicationSpec(number: 39),
    segments: const [
      Bip85PathSegment(name: 'language', value: 0),
      Bip85PathSegment(name: 'words', value: 12),
      Bip85PathSegment(name: 'index', value: 103),
    ],
  );

  static final nostrWalletManifestKey = Bip85KeyReservation(
    id: 'nostr_wallet_manifest_key',
    deterministicAlias: 'Nostr Wallet Manifest',
    owner: Bip85ReservationOwner.nostr,
    purpose: Bip85ReservationPurpose.nonWalletNostrKey,
    application: const Bip85ApplicationSpec(number: 9000),
    segments: const [
      Bip85PathSegment(name: 'identity', value: 1),
      Bip85PathSegment(name: 'account', value: 1),
    ],
  );

  static final nostrBullnymServerAuthKey = Bip85KeyReservation(
    id: 'nostr_bullnym_server_auth_key',
    deterministicAlias: 'Nostr Bullnym Auth',
    owner: Bip85ReservationOwner.nostr,
    purpose: Bip85ReservationPurpose.nonWalletNostrKey,
    application: const Bip85ApplicationSpec(number: 9000),
    segments: const [
      Bip85PathSegment(name: 'identity', value: 2),
      Bip85PathSegment(name: 'account', value: 1),
    ],
  );

  static final nostrNip05PublicNymVerificationKey = Bip85KeyReservation(
    id: 'nostr_nip05_public_nym_verification_key',
    deterministicAlias: 'Nostr NIP-05 Public Nym Verification',
    owner: Bip85ReservationOwner.nostr,
    purpose: Bip85ReservationPurpose.nonWalletNostrKey,
    application: const Bip85ApplicationSpec(number: 9000),
    segments: const [
      Bip85PathSegment(name: 'identity', value: 3),
      Bip85PathSegment(name: 'account', value: 1),
    ],
  );

  static final keychainManifestEncryptionKey = Bip85KeyReservation(
    id: 'keychain_manifest_encryption_key',
    deterministicAlias: 'Keychain Manifest Encryption',
    owner: Bip85ReservationOwner.keychainManifest,
    purpose: Bip85ReservationPurpose.manifestEncryptionKey,
    application: const Bip85ApplicationSpec(number: 1642),
    segments: const [
      Bip85PathSegment(name: 'namespace', value: 0),
      Bip85PathSegment(name: 'key', value: 1),
    ],
  );

  static final List<Bip85Reservation> all = List.unmodifiable([
    btcpayWalletSeed,
    lightningAddressWalletSeed,
    paymentPageWalletSeed,
    posWalletSeed,
    nostrWalletManifestKey,
    nostrBullnymServerAuthKey,
    nostrNip05PublicNymVerificationKey,
    keychainManifestEncryptionKey,
  ]);
}
