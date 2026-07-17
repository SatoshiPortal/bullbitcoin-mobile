import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/trezor/ui/screens/trezor_import_landing_screen.dart';
import 'package:bb_mobile/features/trezor/ui/screens/trezor_sign_transaction_screen.dart';
import 'package:bb_mobile/features/trezor/ui/screens/trezor_verify_address_screen.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:go_router/go_router.dart';

enum TrezorRoute {
  importTrezor('/trezor-import'),
  trezorVerifyAddress('/trezor-verify-address'),
  trezorSignTransaction('/trezor-sign-transaction');

  final String path;
  const TrezorRoute(this.path);
}

class TrezorVerifyAddressRouteParams {
  final String address;
  final String derivationPath;
  final ScriptType scriptType;
  final bool isTestnet;

  const TrezorVerifyAddressRouteParams({
    required this.address,
    required this.derivationPath,
    required this.scriptType,
    required this.isTestnet,
  });
}

class TrezorSignTransactionRouteParams {
  final String psbt;
  final bool isTestnet;
  final ScriptType scriptType;

  const TrezorSignTransactionRouteParams({
    required this.psbt,
    required this.isTestnet,
    required this.scriptType,
  });
}

class TrezorRouter {
  static final routes = [
    GoRoute(
      name: TrezorRoute.importTrezor.name,
      path: TrezorRoute.importTrezor.path,
      builder: (context, state) => const TrezorImportLandingScreen(),
    ),
    GoRoute(
      name: TrezorRoute.trezorVerifyAddress.name,
      path: TrezorRoute.trezorVerifyAddress.path,
      // Bounce to wallet home when
      // params are missing or the wrong type; the user re-initiates the
      // verify from the receive screen, which always pushes valid params.
      redirect: (context, state) =>
          state.extra is TrezorVerifyAddressRouteParams
          ? null
          : WalletRoute.walletHome.path,
      builder: (context, state) {
        final extra = state.extra! as TrezorVerifyAddressRouteParams;
        return TrezorVerifyAddressScreen(params: extra);
      },
    ),
    GoRoute(
      name: TrezorRoute.trezorSignTransaction.name,
      path: TrezorRoute.trezorSignTransaction.path,
      // Send screen always pushes valid params; if we
      // got here without them, something went wrong upstream and the
      // safest move is to bounce home.
      redirect: (context, state) =>
          state.extra is TrezorSignTransactionRouteParams
          ? null
          : WalletRoute.walletHome.path,
      builder: (context, state) {
        final extra = state.extra! as TrezorSignTransactionRouteParams;
        return TrezorSignTransactionScreen(params: extra);
      },
    ),
  ];
}
