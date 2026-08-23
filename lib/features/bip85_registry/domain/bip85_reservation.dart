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

  bool matchesExactPath(String candidate) => path == candidate;
}
