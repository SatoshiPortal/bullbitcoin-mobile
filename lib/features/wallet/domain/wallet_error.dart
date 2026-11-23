/// The legacy throwing catalog could not find the requested wallet.
final class WalletNotFoundException implements Exception {
  final String walletId;

  const WalletNotFoundException(this.walletId);
}

class WalletAlreadyExistsException implements Exception {
  final String walletId;

  const WalletAlreadyExistsException(this.walletId);
}
