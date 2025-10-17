import 'package:bb_mobile/features/bitbox/bitbox_action.dart';
import 'package:bb_mobile/features/bitbox/ui/screens/bitbox_action_screen.dart';
import 'package:go_router/go_router.dart';

enum BitBoxRoute {
  importBitBox('/bitbox-import'),
  bitboxSignTransaction('/bitbox-sign-transaction'),
  bitboxVerifyAddress('/bitbox-verify-address');

  final String path;

  const BitBoxRoute(this.path);
}

class BitBoxRouter {
  static final routes = [
    GoRoute(
      name: BitBoxRoute.importBitBox.name,
      path: BitBoxRoute.importBitBox.path,
      builder: (context, state) {
        final extra = state.extra as BitBoxRouteParams?;
        return BitBoxActionScreen(
          action: const BitBoxAction.importWallet(),
          parameters: extra,
        );
      },
    ),
    GoRoute(
      name: BitBoxRoute.bitboxSignTransaction.name,
      path: BitBoxRoute.bitboxSignTransaction.path,
      builder: (context, state) {
        final extra = state.extra as BitBoxRouteParams?;
        return BitBoxActionScreen(
          action: const BitBoxAction.signTransaction(),
          parameters: extra,
        );
      },
    ),
    GoRoute(
      name: BitBoxRoute.bitboxVerifyAddress.name,
      path: BitBoxRoute.bitboxVerifyAddress.path,
      builder: (context, state) {
        final extra = state.extra as BitBoxRouteParams?;
        return BitBoxActionScreen(
          action: const BitBoxAction.verifyAddress(),
          parameters: extra,
        );
      },
    ),
  ];
}
