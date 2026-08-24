import 'package:bb_mobile/features/bitbox/bitbox_action.dart';
import 'package:bb_mobile/features/bitbox/ui/screens/bitbox_action_screen.dart';
import 'package:bb_mobile/features/bitbox/public/bitbox_facade.dart';
import 'package:go_router/go_router.dart';

enum BitBoxRoute {
  importBitBox('/bitbox-import'),
  bitboxRegisterWalletPolicy('/bitbox-register-wallet-policy'),
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
      name: BitBoxRoute.bitboxRegisterWalletPolicy.name,
      path: BitBoxRoute.bitboxRegisterWalletPolicy.path,
      builder: (context, state) {
        final request = state.extra as RegisterBitBoxWalletPolicyRequest;
        return BitBoxActionScreen(
          action: const BitBoxAction.registerWalletPolicy(),
          parameters: BitBoxRouteParams(walletPolicy: request),
        );
      },
    ),
    GoRoute(
      name: BitBoxRoute.bitboxSignTransaction.name,
      path: BitBoxRoute.bitboxSignTransaction.path,
      builder: (context, state) {
        final extra = state.extra;
        return BitBoxActionScreen(
          action: const BitBoxAction.signTransaction(),
          parameters: extra is SignBitBoxWalletPolicyRequest
              ? BitBoxRouteParams(walletPolicy: extra)
              : extra as BitBoxRouteParams?,
        );
      },
    ),
    GoRoute(
      name: BitBoxRoute.bitboxVerifyAddress.name,
      path: BitBoxRoute.bitboxVerifyAddress.path,
      builder: (context, state) {
        final extra = state.extra;
        return BitBoxActionScreen(
          action: const BitBoxAction.verifyAddress(),
          parameters: extra is VerifyBitBoxWalletPolicyAddressRequest
              ? BitBoxRouteParams(walletPolicy: extra)
              : extra as BitBoxRouteParams?,
        );
      },
    ),
  ];
}
