sealed class Label {
  final String? label;
  final String? origin;

  Label({this.label, this.origin});
}

class UtxoLabel extends Label {
  final String txId;
  final int index;
  final bool? isSpendable;

  UtxoLabel({
    super.label,
    super.origin,
    required this.txId,
    required this.index,
    this.isSpendable,
  });

  UtxoLabel setSpendable(bool isSpendable) {
    // Here we could issue an event if a utxo is marked as spendable so that other parts
    // of the app can react to it if needed.

    return UtxoLabel(
      label: label,
      origin: origin,
      txId: txId,
      index: index,
      isSpendable: isSpendable,
    );
  }
}

class AddressLabel extends Label {
  final String address;

  AddressLabel({super.label, super.origin, required this.address});
}

class TransactionLabel extends Label {
  final String txId;

  TransactionLabel({super.label, super.origin, required this.txId});
}
