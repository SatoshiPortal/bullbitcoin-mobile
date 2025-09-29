class UtxoViewModel {
  final String walletId;
  final String txId;
  final int index;
  final int valueSat;
  final String address;
  final bool isSpendable;
  final List<String> labels;
  final List<String> addressLabels;
  final List<String> transactionLabels;

  const UtxoViewModel({
    required this.walletId,
    required this.txId,
    required this.index,
    required this.valueSat,
    required this.address,
    required this.isSpendable,
    required this.labels,
    required this.addressLabels,
    required this.transactionLabels,
  });
}
