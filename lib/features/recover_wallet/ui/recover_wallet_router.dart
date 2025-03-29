import 'package:bb_mobile/features/recover_wallet/ui/screens/physical/recover_wallet_flow.dart';

import 'package:go_router/go_router.dart';

enum RecoverWalletSubroute {
  physical('recover-physical');

  final String path;

  const RecoverWalletSubroute(this.path);
}

class RecoverWalletRouter {
  static final routes = [
    GoRoute(
      name: RecoverWalletSubroute.physical.name,
      path: RecoverWalletSubroute.physical.path,
      builder: (context, state) => RecoverPhysicalWalletFlow(
        fromOnboarding: (state.extra as bool?) ?? false,
      ),
    ),
  ];
}
