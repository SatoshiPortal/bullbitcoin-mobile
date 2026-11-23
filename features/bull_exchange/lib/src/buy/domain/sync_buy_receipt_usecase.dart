import 'package:exchange/exchange.dart';

/// Scoped to one Buy flow. Only creation can associate an order with a wallet.
class SyncBuyReceiptUsecase {
  final Future<void> Function(String) _pollWallet;
  ({String orderId, String walletId})? _destination;
  String? _requestedOrderId;

  SyncBuyReceiptUsecase(this._pollWallet);

  /// Capture the creation input once; refreshes never use the current selection.
  void execute({required BuyOrder order, String? destinationWalletId}) {
    if (destinationWalletId != null) {
      _destination = (orderId: order.orderId, walletId: destinationWalletId);
    }
    final destination = _destination;
    if (destination == null ||
        destination.orderId != order.orderId ||
        _requestedOrderId == order.orderId ||
        order.payoutStatus != OrderPayoutStatus.completed) {
      return;
    }
    _requestedOrderId = order.orderId;
    _pollWallet(destination.walletId).ignore();
  }
}
