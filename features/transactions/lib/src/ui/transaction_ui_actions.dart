import 'package:swaps/order_swaps.dart';
import 'package:exchange/exchange.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/entities/wallet_transaction.dart';

/// Callbacks to flows and widgets owned by the host application.
final class TransactionUiActions {
  final void Function(BuildContext) openExchange;
  final void Function(BuildContext) openWalletHome;
  final Future<void> Function(BuildContext) refreshWallets;
  final Widget Function(BuildContext, String orderId) accelerateOrder;
  final void Function(BuildContext, FiatPaymentOrder) showReceipt;
  final void Function(BuildContext, WalletTransaction)
  accelerateWalletTransaction;
  final Widget Function(String address, TextStyle style) addressViewer;
  final Widget Function(OrderSwapRecord orderSwap) orderSwapUnderReview;

  const TransactionUiActions({
    required this.openExchange,
    required this.openWalletHome,
    required this.refreshWallets,
    required this.accelerateOrder,
    required this.showReceipt,
    required this.accelerateWalletTransaction,
    required this.addressViewer,
    required this.orderSwapUnderReview,
  });
}
