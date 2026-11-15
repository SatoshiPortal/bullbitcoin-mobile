/// No timeout, absence or recovery operation grants spend permission.
enum BitcoinSpendStatus {
  ready,
  pending,
  unavailable,

  /// Another operation, usually a sync, holds the wallet: retry shortly.
  busy,

  /// The tracked transaction to replace has not been observed by a sync yet.
  replacementPending,
}

final class BitcoinBroadcastReceipt {
  final String txid;
  final bool durable;
  const BitcoinBroadcastReceipt(this.txid, {required this.durable});
}
