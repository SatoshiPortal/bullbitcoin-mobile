import 'package:bb_mobile/features/connect_hardware_wallet/connect_hardware_wallet_page.dart';
import 'package:go_router/go_router.dart';

enum ConnectHardwareWalletRoute {
  connectHardwareWallet('/connect-hardware-wallet');

  final String path;

  const ConnectHardwareWalletRoute(this.path);
}

class ConnectHardwareWalletRouter {
  static final route = GoRoute(
    name: ConnectHardwareWalletRoute.connectHardwareWallet.name,
    path: ConnectHardwareWalletRoute.connectHardwareWallet.path,
    builder: (context, state) => const ConnectHardwareWalletPage(),
  );
}
