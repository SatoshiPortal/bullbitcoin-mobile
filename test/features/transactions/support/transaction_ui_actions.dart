import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:transactions/setup.dart';

final transactionUiActions = TransactionUiActions(
  openExchange: (context) => context.goNamed('exchangeHome'),
  openWalletHome: (context) => context.goNamed('walletHome'),
  refreshWallets: (_) async {},
  accelerateOrder: (_, _) => const SizedBox.shrink(),
  showReceipt: (_, _) {},
  accelerateWalletTransaction: (_, _) {},
  orderSwapUnderReview: (_) => const SizedBox.shrink(),
  addressViewer: (address, style) => Text(address, style: style),
);
