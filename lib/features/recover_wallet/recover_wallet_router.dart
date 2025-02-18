// TODO: This should probably be moved to the Onboarding feature and router
import 'package:bb_mobile/features/recover_wallet/presentation/flow/recover_wallet_flow.dart';
import 'package:go_router/go_router.dart';

enum RecoverWalletRoute {
  recoverWallet('/recover-wallet');

  final String path;

  const RecoverWalletRoute(this.path);
}

class RecoverWalletRouter {
  static final route = GoRoute(
    name: RecoverWalletRoute.recoverWallet.name,
    path: RecoverWalletRoute.recoverWallet.path,
    builder: (context, state) => const RecoverWalletFlow(),
  );
}
