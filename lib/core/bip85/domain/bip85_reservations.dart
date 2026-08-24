import 'package:bb_mobile/core/utils/recoverbull_bip85.dart';

enum Bip85ReservationOwner {
  btcpay,
  lightningAddress,
  paymentPage,
  pos,
  nostr,
  walletBackup,
}

enum Bip85ReservationPurpose {
  walletSeed,
  nonWalletNostrKey,
  backupEncryptionKey,
}

final class Bip85Reservation {
  final String id;
  final String deterministicAlias;
  final Bip85ReservationOwner owner;
  final Bip85ReservationPurpose purpose;
  final int application;
  final String path;
  final int index;

  const Bip85Reservation({
    required this.id,
    required this.deterministicAlias,
    required this.owner,
    required this.purpose,
    required this.application,
    required this.path,
    required this.index,
  });

  bool get isWalletSeed => purpose == Bip85ReservationPurpose.walletSeed;

  int get walletIndex {
    if (!isWalletSeed) throw StateError('Reservation is not a wallet seed');
    return index;
  }
}

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
  static const pointOfSaleWalletSeed = Bip85Reservation(
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
    pointOfSaleWalletSeed,
    nostrWalletBackupKey,
    nostrBullnymServerAuthKey,
    nostrNip05PublicNymVerificationKey,
    walletBackupEncryptionKey,
  ];

  static final reservedWalletSeedIndices = Set<int>.unmodifiable(
    all.where((item) => item.isWalletSeed).map((item) => item.walletIndex),
  );
  static final reservedWalletSeedPaths = Set<String>.unmodifiable(
    all.where((item) => item.isWalletSeed).map((item) => item.path),
  );
  static final reservedPaths = Set<String>.unmodifiable(
    all.map((item) => item.path),
  );
  static final reservedPathPrefixes = Set<String>.unmodifiable({
    RecoverbullBip85Utils.vaultKeyPathPrefix,
  });

  static bool isReservedPath(String path) {
    final candidate = path.trim();
    return reservationByExactPath(candidate) != null ||
        isRecoverbullVaultKeyPath(candidate);
  }

  static bool isRecoverbullVaultKeyPath(String path) {
    final candidate = path.trim();
    if (!candidate.startsWith(RecoverbullBip85Utils.vaultKeyPathPrefix)) {
      return false;
    }
    final indexText = candidate.substring(
      RecoverbullBip85Utils.vaultKeyPathPrefix.length,
    );
    if (!indexText.endsWith("'")) return false;
    final index = int.tryParse(indexText.substring(0, indexText.length - 1));
    return index != null &&
        index >= 0 &&
        index <= RecoverbullBip85Utils.maxVaultKeyIndex &&
        candidate == '${RecoverbullBip85Utils.vaultKeyPathPrefix}$index\'';
  }

  static bool isNostrAppReservedIdentity(int identity) =>
      identity >= nostrAppReservedIdentityStart &&
      identity <= nostrAppReservedIdentityEnd;

  static String nostrUserKeyPath(int identity) {
    if (identity < nostrUserIdentityStart ||
        identity > nostrUserIdentityEnd ||
        isNostrAppReservedIdentity(identity)) {
      throw ArgumentError.value(identity, 'identity');
    }
    return "$nostrApplicationNumber'/$identity'/$nostrUserAccount'";
  }

  static int? nostrUserKeyIdentity(String path) {
    final candidate = path.trim();
    final parts = candidate.split('/');
    if (parts.length != 3 ||
        parts.first != "$nostrApplicationNumber'" ||
        parts.last != "$nostrUserAccount'") {
      return null;
    }
    final middle = parts[1];
    final identity = middle.endsWith("'")
        ? int.tryParse(middle.substring(0, middle.length - 1))
        : null;
    if (identity == null ||
        identity < nostrUserIdentityStart ||
        identity > nostrUserIdentityEnd ||
        isNostrAppReservedIdentity(identity)) {
      return null;
    }
    return nostrUserKeyPath(identity) == candidate ? identity : null;
  }

  static bool isNostrUserKeyPath(String path) =>
      nostrUserKeyIdentity(path) != null;

  static Bip85Reservation? reservationById(String id) =>
      all.where((item) => item.id == id).firstOrNull;

  static Bip85Reservation? reservationByExactPath(String path) =>
      all.where((item) => item.path == path.trim()).firstOrNull;
}
