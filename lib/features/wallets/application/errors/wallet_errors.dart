class WalletNotFoundError implements Exception {
  final int walletId;

  const WalletNotFoundError({required this.walletId});

  @override
  String toString() => 'WalletNotFoundError: Wallet with ID $walletId not found.';
}