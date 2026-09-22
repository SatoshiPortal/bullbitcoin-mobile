import 'package:bb_mobile/features/default_wallets/public/default_wallets_facade.dart';
import 'package:go_router/go_router.dart';

enum DefaultWalletsRoute {
  defaultWallets('exchange-bitcoin-wallets');

  final String path;

  const DefaultWalletsRoute(this.path);
}

class DefaultWalletsRouter {
  static GoRoute route({required DefaultWalletsFacade facade}) => GoRoute(
    name: DefaultWalletsRoute.defaultWallets.name,
    path: DefaultWalletsRoute.defaultWallets.path,
    builder: (context, state) => facade.buildScreen(),
  );
}
