final class FrozenWalletOutpointModel {
  final String walletId;
  final String txId;
  final int vout;

  const FrozenWalletOutpointModel({
    required this.walletId,
    required this.txId,
    required this.vout,
  });
}
