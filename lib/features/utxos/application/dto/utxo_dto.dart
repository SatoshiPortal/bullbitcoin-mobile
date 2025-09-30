class UtxoDto {
  final String walletId;
  final String txId;
  final int index;
  final String address;
  final int valueSat;
  final bool isSpendable;
  final List<String> outputLabels;
  final List<String> addressLabels;
  final List<String> transactionLabels;

  UtxoDto({
    required this.walletId,
    required this.txId,
    required this.index,
    required this.address,
    required this.valueSat,
    required this.isSpendable,
    required this.outputLabels,
    required this.addressLabels,
    required this.transactionLabels,
  });
}
