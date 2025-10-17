class GetWalletUtxosRequest {
  final String walletId;
  final int? limit;
  final int? offset;

  GetWalletUtxosRequest({required this.walletId, this.limit, this.offset});
}
