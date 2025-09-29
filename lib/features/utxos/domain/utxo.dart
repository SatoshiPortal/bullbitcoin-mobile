class Utxo {
  final String txId;
  final int index;
  final String address;
  final int valueSat;

  Utxo({
    required this.txId,
    required this.index,
    required this.address,
    required this.valueSat,
  });
}
