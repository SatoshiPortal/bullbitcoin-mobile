import 'package:flutter/widgets.dart';

class WalletHomeDesktopAction {
  const WalletHomeDesktopAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class WalletHomeDesktopConfig {
  const WalletHomeDesktopConfig({
    this.buildActions,
    this.buildExchangePanel,
    this.buildRecentTransactions,
    this.onOpenTransactions,
  });

  final List<WalletHomeDesktopAction> Function(BuildContext)? buildActions;
  final WidgetBuilder? buildExchangePanel;
  final WidgetBuilder? buildRecentTransactions;
  final void Function(BuildContext)? onOpenTransactions;
}
