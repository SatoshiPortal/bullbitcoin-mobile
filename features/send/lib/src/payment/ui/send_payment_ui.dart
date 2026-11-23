import 'package:flutter/widgets.dart';
import 'package:swaps/order_swaps.dart';
import 'package:sync/sync.dart' show WalletKey;

class SendPaymentUi extends InheritedWidget {
  final void Function(BuildContext) openHome;
  final void Function(BuildContext, WalletKey) openCoins;
  final Widget Function(OrderSwapRecord) orderUnderReview;
  final ImageProvider arrowImage;
  final ImageProvider successImage;

  const SendPaymentUi({
    super.key,
    required this.openHome,
    required this.openCoins,
    required this.orderUnderReview,
    required this.arrowImage,
    required this.successImage,
    required super.child,
  });

  static SendPaymentUi? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SendPaymentUi>();

  static SendPaymentUi of(BuildContext context) {
    final ui = maybeOf(context);
    if (ui == null) throw StateError('Payment UI is not mounted');
    return ui;
  }

  @override
  bool updateShouldNotify(SendPaymentUi oldWidget) =>
      openHome != oldWidget.openHome ||
      openCoins != oldWidget.openCoins ||
      orderUnderReview != oldWidget.orderUnderReview ||
      arrowImage != oldWidget.arrowImage ||
      successImage != oldWidget.successImage;
}
