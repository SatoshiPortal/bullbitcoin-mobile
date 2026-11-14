import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/default_wallets/public/default_wallets_facade.dart';
import 'package:bb_mobile/locator.dart';
import 'package:go_router/go_router.dart';

enum DefaultWalletsRoute {
  defaultWallets('exchange-bitcoin-wallets');

  final String path;

  const DefaultWalletsRoute(this.path);
}

class DefaultWalletsRouter {
  static final route = GoRoute(
    name: DefaultWalletsRoute.defaultWallets.name,
    path: DefaultWalletsRoute.defaultWallets.path,
    redirect: (context, state) async {
      final settings = await locator<SettingsRepository>().fetch();
      return NetworkCapabilities.supports(
            BitcoinNetwork.fromName(settings.environment.name),
            NetworkCapability.exchange,
          )
          ? null
          : '/wallet';
    },
    builder: (context, state) => locator<DefaultWalletsFacade>().buildScreen(),
  );
}
