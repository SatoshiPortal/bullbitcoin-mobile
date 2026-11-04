import 'wallet_transaction_observation.dart';

class WalletTransactionPage {
  final List<WalletTransactionObservation> items;
  final String? nextCursor;
  final int revision;
  WalletTransactionPage(
    List<WalletTransactionObservation> items,
    this.nextCursor,
    this.revision,
  ) : items = List.unmodifiable(items);
}
