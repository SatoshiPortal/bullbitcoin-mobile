class GetUtxoRequest {
  final String walletId;
  final String txId;
  final int index;

  GetUtxoRequest({
    required this.walletId,
    required this.txId,
    required this.index,
  });
}
