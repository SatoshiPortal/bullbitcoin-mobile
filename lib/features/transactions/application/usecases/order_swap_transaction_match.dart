import 'package:bb_mobile/features/swap/public/swap_facade.dart';

typedef OrderSwapWalletLeg = ({String txId, String walletId});

OrderSwapWalletLeg? canonicalOrderSwapWalletLeg(OrderSwapRecord record) {
  final walletId = record.canonicalWalletId;
  final txId = record.canonicalWalletTransactionId;
  return walletId == null || txId == null
      ? null
      : (txId: txId, walletId: walletId);
}

Set<OrderSwapWalletLeg> secondaryOrderSwapWalletLegs(OrderSwapRecord record) {
  final canonical = canonicalOrderSwapWalletLeg(record);
  final legs = <OrderSwapWalletLeg>{};
  final sourceWalletId = record.sourceWalletId;
  final sourceTxId =
      record.localPayinTransactionId ??
      record.transactionIdForNetwork(record.inNetwork);
  if (sourceWalletId != null && sourceTxId != null) {
    legs.add((txId: sourceTxId, walletId: sourceWalletId));
  }
  final destinationWalletId = record.destinationWalletId;
  final destinationTxId = record.transactionIdForNetwork(record.outNetwork);
  if (destinationWalletId != null && destinationTxId != null) {
    legs.add((txId: destinationTxId, walletId: destinationWalletId));
  }
  if (canonical != null) legs.remove(canonical);
  return legs;
}

bool orderSwapReferencesTransaction(OrderSwapRecord record, String txId) =>
    record.localPayinTransactionId == txId ||
    record.order?.bitcoinTransactionId == txId ||
    record.order?.liquidTransactionId == txId;
