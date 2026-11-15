import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show Network;

final class AddressTransaction {
  final String txid;
  final int height;

  const AddressTransaction({required this.txid, required this.height});

  bool get isConfirmed => height > 0;

  @override
  bool operator ==(Object other) =>
      other is AddressTransaction &&
      other.txid == txid &&
      other.height == height;

  @override
  int get hashCode => Object.hash(txid, height);
}

final class AddressOverview {
  final String address;
  final Network network;
  final int confirmedSat;
  final int unconfirmedSat;
  final List<AddressTransaction> transactions;

  AddressOverview({
    required this.address,
    required this.network,
    required this.confirmedSat,
    required this.unconfirmedSat,
    required List<AddressTransaction> transactions,
  }) : transactions = List.unmodifiable(transactions) {
    if (confirmedSat < 0) {
      throw ArgumentError.value(confirmedSat, 'confirmedSat', 'is negative');
    }
  }

  int get transactionCount => transactions.length;
}
