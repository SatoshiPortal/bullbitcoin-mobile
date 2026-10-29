import 'package:bb_mobile/locator.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';
import 'public/wallet_sync_facade.dart';

class WalletSyncRouter {
  static const statusRouteName = 'wallet-sync-status';
  static final route = GoRoute(
    path: '/wallet-sync/:walletId/status',
    name: statusRouteName,
    builder: (context, state) => switch (state.pathParameters['walletId']) {
      final id? => locator<WalletSyncFacade>().networkStatusForWallet(id),
      null => const SizedBox.shrink(),
    },
  );
}
