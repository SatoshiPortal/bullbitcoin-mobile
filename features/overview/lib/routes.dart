import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

enum WalletRoute {
  walletHome('/wallet'),
  walletDetail('/wallet/:walletId');

  const WalletRoute(this.path);

  final String path;
}

/// Builds the historical wallet detail route without changing its placement.
GoRoute walletDetailRoute({
  required Widget Function(BuildContext context, String walletId) builder,
}) => GoRoute(
  name: WalletRoute.walletDetail.name,
  path: WalletRoute.walletDetail.path,
  builder: (context, state) {
    final walletId = state.pathParameters['walletId'];
    if (walletId == null) return const SizedBox.shrink();
    return builder(context, walletId);
  },
);
