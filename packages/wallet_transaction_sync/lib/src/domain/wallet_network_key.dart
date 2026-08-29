class WalletNetworkKey {
  final String walletId;
  final String chain;
  final String network;

  const WalletNetworkKey(this.walletId, this.chain, this.network);

  @override
  bool operator ==(Object other) =>
      other is WalletNetworkKey &&
      other.walletId == walletId &&
      other.chain == chain &&
      other.network == network;
  @override
  int get hashCode => Object.hash(walletId, chain, network);
  @override
  String toString() => '$walletId/$chain/$network';
}
