class SwapTxOutspend {
  final String? txid;
  final DateTime? timestamp;

  const SwapTxOutspend({this.txid, this.timestamp});
}

enum SwapDirection { bitcoinToLiquid, liquidToBitcoin }
