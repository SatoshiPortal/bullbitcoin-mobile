import 'package:bb_mobile/features/bip85_registry/domain/bip85_reservation.dart';

abstract final class Bip85Reservations {
  static const nostrApplicationNumber = 128002;
  static const nostrUserKeyReservationId = 'nostr_user_key';
  static const nostrUserIdentityStart = 1;
  static const nostrUserIdentityEnd = 0x7fffffff;
  static const nostrUserAccount = 1;
  static const nostrAppReservedIdentityStart = 100;
  static const nostrAppReservedIdentityEnd = 199;

  static const btcpayWalletSeed = Bip85Reservation(
    id: 'btcpay_wallet_seed',
    deterministicAlias: 'BTCPay',
    owner: Bip85ReservationOwner.btcpay,
    purpose: Bip85ReservationPurpose.walletSeed,
    application: 39,
    path: "39'/0'/12'/100'",
    index: 100,
  );
  static const lightningAddressWalletSeed = Bip85Reservation(
    id: 'lightning_address_wallet_seed',
    deterministicAlias: 'Lightning Address',
    owner: Bip85ReservationOwner.lightningAddress,
    purpose: Bip85ReservationPurpose.walletSeed,
    application: 39,
    path: "39'/0'/12'/101'",
    index: 101,
  );
  static const paymentPageWalletSeed = Bip85Reservation(
    id: 'payment_page_wallet_seed',
    deterministicAlias: 'Payment Page',
    owner: Bip85ReservationOwner.paymentPage,
    purpose: Bip85ReservationPurpose.walletSeed,
    application: 39,
    path: "39'/0'/12'/102'",
    index: 102,
  );
  static const posWalletSeed = Bip85Reservation(
    id: 'pos_wallet_seed',
    deterministicAlias: 'Point of Sale',
    owner: Bip85ReservationOwner.pos,
    purpose: Bip85ReservationPurpose.walletSeed,
    application: 39,
    path: "39'/0'/12'/103'",
    index: 103,
  );
  static const nostrWalletBackupKey = Bip85Reservation(
    id: 'nostr_wallet_backup_key',
    deterministicAlias: 'Nostr Wallet Backup',
    owner: Bip85ReservationOwner.nostr,
    purpose: Bip85ReservationPurpose.nonWalletNostrKey,
    application: nostrApplicationNumber,
    path: "128002'/100'/1'",
    index: 100,
  );
  static const nostrBullnymServerAuthKey = Bip85Reservation(
    id: 'nostr_bullnym_server_auth_key',
    deterministicAlias: 'Nostr Bullnym Auth',
    owner: Bip85ReservationOwner.nostr,
    purpose: Bip85ReservationPurpose.nonWalletNostrKey,
    application: nostrApplicationNumber,
    path: "128002'/101'/1'",
    index: 101,
  );
  static const nostrNip05PublicNymVerificationKey = Bip85Reservation(
    id: 'nostr_nip05_public_nym_verification_key',
    deterministicAlias: 'Nostr NIP-05 Public Nym Verification',
    owner: Bip85ReservationOwner.nostr,
    purpose: Bip85ReservationPurpose.nonWalletNostrKey,
    application: nostrApplicationNumber,
    path: "128002'/102'/1'",
    index: 102,
  );
  static const walletBackupEncryptionKey = Bip85Reservation(
    id: 'wallet_backup_encryption_key',
    deterministicAlias: 'Wallet Backup Encryption',
    owner: Bip85ReservationOwner.walletBackup,
    purpose: Bip85ReservationPurpose.backupEncryptionKey,
    application: 1642,
    path: "1642'/0'/1'",
    index: 1,
  );

  static const all = <Bip85Reservation>[
    btcpayWalletSeed,
    lightningAddressWalletSeed,
    paymentPageWalletSeed,
    posWalletSeed,
    nostrWalletBackupKey,
    nostrBullnymServerAuthKey,
    nostrNip05PublicNymVerificationKey,
    walletBackupEncryptionKey,
  ];
}
